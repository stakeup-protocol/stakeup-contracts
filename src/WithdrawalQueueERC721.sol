// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWstUSD, WithdrawalQueue} from "./WithdrawalQueue.sol";
import {INFTDescriptor} from "./interfaces/INFTDescriptor.sol";

contract WithdrawalQueueERC721 is IERC721Metadata, IERC4906, WithdrawalQueue {
    using Address for address;
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    BaseURI internal _baseURI;
    address internal _nftDescriptorAddress;

    bytes32 public constant MANAGE_TOKEN_URI_ROLE =
        keccak256("MANAGE_TOKEN_URI_ROLE");

    // @notion simple wrapper for base URI string
    //  Solidity does not allow to store string in UnstructuredStorage
    struct BaseURI {
        string value;
    }

    event BaseURISet(string baseURI);
    event NftDescriptorAddressSet(address nftDescriptorAddress);

    error ApprovalToOwner();
    error ApproveToCaller();
    error NotOwnerOrApprovedForAll(address sender);
    error NotOwnerOrApproved(address sender);
    error TransferFromIncorrectOwner(address from, address realOwner);
    error TransferToZeroAddress();
    error TransferFromZeroAddress();
    error TransferToThemselves();
    error TransferToNonIERC721Receiver(address);
    error InvalidOwnerAddress(address);
    error StringTooLong(string str);
    error ZeroMetadata();

    // short strings for ERC721 name and symbol
    bytes32 private immutable NAME;
    bytes32 private immutable SYMBOL;

    /// @param _wstUSD address of WstUSD contract
    /// @param _name IERC721Metadata name string. Should be shorter than 32 bytes
    /// @param _symbol IERC721Metadata symbol string. Should be shorter than 32 bytes
    constructor(
        address _wstUSD,
        address _underlying,
        string memory _name,
        string memory _symbol
    ) WithdrawalQueue(IWstUSD(_wstUSD), IERC20(_underlying)) {
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0)
            revert ZeroMetadata();
        NAME = _toBytes32(_name);
        SYMBOL = _toBytes32(_symbol);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, AccessControlEnumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            // 0x49064906 is magic number ERC4906 interfaceId as defined in the standard https://eips.ethereum.org/EIPS/eip-4906
            interfaceId == bytes4(0x49064906) ||
            super.supportsInterface(interfaceId);
    }

    /// @dev See {IERC721Metadata-name}.
    function name() external view override returns (string memory) {
        return _toString(NAME);
    }

    /// @dev See {IERC721Metadata-symbol}.
    function symbol() external view override returns (string memory) {
        return _toString(SYMBOL);
    }

    /// @dev See {IERC721Metadata-tokenURI}.
    /// @dev If NFTDescriptor address isn't set the `baseURI` would be used for generating erc721 tokenURI. In case
    ///  NFTDescriptor address is set it would be used as a first-priority method.
    function tokenURI(
        uint256 _requestId
    ) public view virtual override returns (string memory) {
        if (!_existsAndNotClaimed(_requestId))
            revert InvalidRequestId(_requestId);

        if (_nftDescriptorAddress != address(0)) {
            return
                INFTDescriptor(_nftDescriptorAddress).constructTokenURI(
                    _requestId
                );
        } else {
            return _constructTokenUri(_requestId);
        }
    }

    /// @notice Base URI for computing {tokenURI}. If set, the resulting URI for each
    /// token will be the concatenation of the `baseURI` and the `_requestId`.
    function getBaseURI() external view returns (string memory) {
        return _baseURI.value;
    }

    /// @notice Sets the Base URI for computing {tokenURI}. It does not expect the ending slash in provided string.
    /// @dev If NFTDescriptor address isn't set the `baseURI` would be used for generating erc721 tokenURI. In case
    ///  NFTDescriptor address is set it would be used as a first-priority method.
    function setBaseURI(
        string calldata __baseURI
    ) external onlyRole(MANAGE_TOKEN_URI_ROLE) {
        _baseURI.value = __baseURI;
        emit BaseURISet(__baseURI);
    }

    /// @notice Address of NFTDescriptor contract that is responsible for tokenURI generation.
    function getNFTDescriptorAddress() external view returns (address) {
        return _nftDescriptorAddress;
    }

    /// @notice Sets the address of NFTDescriptor contract that is responsible for tokenURI generation.
    /// @dev If NFTDescriptor address isn't set the `baseURI` would be used for generating erc721 tokenURI. In case
    ///  NFTDescriptor address is set it would be used as a first-priority method.
    function setNFTDescriptorAddress(
        address __nftDescriptorAddress
    ) external onlyRole(MANAGE_TOKEN_URI_ROLE) {
        _nftDescriptorAddress = __nftDescriptorAddress;
        emit NftDescriptorAddressSet(__nftDescriptorAddress);
    }

    /// @notice Finalize requests from last finalized one up to `_lastRequestIdToBeFinalized`
    /// @dev usd to finalize all the requests should be calculated using `prefinalize()` and sent along
    function finalize(uint256 _lastRequestIdToBeFinalized) external payable {
        _requireNotPaused();
        _checkRole(FINALIZE_ROLE, msg.sender);

        uint256 firstFinalizedRequestId = getLastFinalizedRequestId() + 1;

        _finalize(_lastRequestIdToBeFinalized, msg.value);

        // ERC4906 metadata update event
        // We are updating all unfinalized to make it look different as they move closer to finalization in the future
        emit BatchMetadataUpdate(firstFinalizedRequestId, getLastRequestId());
    }

    /// @dev See {IERC721-balanceOf}.
    function balanceOf(
        address _owner
    ) external view override returns (uint256) {
        if (_owner == address(0)) revert InvalidOwnerAddress(_owner);
        return _requestsByOwner[_owner].length();
    }

    /// @dev See {IERC721-ownerOf}.
    function ownerOf(
        uint256 _requestId
    ) public view override returns (address) {
        if (_requestId == 0 || _requestId > getLastRequestId())
            revert InvalidRequestId(_requestId);

        WithdrawalRequest storage request = _queue[_requestId];
        if (request.claimed) revert RequestAlreadyClaimed(_requestId);

        return request.owner;
    }

    /// @dev See {IERC721-approve}.
    function approve(address _to, uint256 _requestId) external override {
        address owner = ownerOf(_requestId);
        if (_to == owner) revert ApprovalToOwner();
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender))
            revert NotOwnerOrApprovedForAll(msg.sender);

        _approve(_to, _requestId);
    }

    /// @dev See {IERC721-getApproved}.
    function getApproved(
        uint256 _requestId
    ) external view override returns (address) {
        if (!_existsAndNotClaimed(_requestId))
            revert InvalidRequestId(_requestId);

        return _tokenApprovals[_requestId];
    }

    /// @dev See {IERC721-setApprovalForAll}.
    function setApprovalForAll(
        address _operator,
        bool _approved
    ) external override {
        _setApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @dev See {IERC721-isApprovedForAll}.
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view override returns (bool) {
        return _operatorApprovals[_owner][_operator];
    }

    /// @dev See {IERC721-safeTransferFrom}.
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _requestId
    ) external override {
        safeTransferFrom(_from, _to, _requestId, "");
    }

    /// @dev See {IERC721-safeTransferFrom}.
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _requestId,
        bytes memory _data
    ) public override {
        _transfer(_from, _to, _requestId);
        if (!_checkOnERC721Received(_from, _to, _requestId, _data)) {
            revert TransferToNonIERC721Receiver(_to);
        }
    }

    /// @dev See {IERC721-transferFrom}.
    function transferFrom(
        address _from,
        address _to,
        uint256 _requestId
    ) external override {
        _transfer(_from, _to, _requestId);
    }

    /// @dev Transfers `_requestId` from `_from` to `_to`.
    ///  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
    ///
    /// Requirements:
    ///
    /// - `_to` cannot be the zero address.
    /// - `_requestId` request must not be claimed and be owned by `_from`.
    /// - `msg.sender` should be approved, or approved for all, or owner
    function _transfer(
        address _from,
        address _to,
        uint256 _requestId
    ) internal {
        if (_to == address(0)) revert TransferToZeroAddress();
        if (_to == _from) revert TransferToThemselves();
        if (_requestId == 0 || _requestId > getLastRequestId())
            revert InvalidRequestId(_requestId);

        WithdrawalRequest storage request = _queue[_requestId];
        if (request.claimed) revert RequestAlreadyClaimed(_requestId);

        if (_from != request.owner)
            revert TransferFromIncorrectOwner(_from, request.owner);
        // here and below we are sure that `_from` is the owner of the request
        address msgSender = msg.sender;
        if (
            !(_from == msgSender ||
                isApprovedForAll(_from, msgSender) ||
                _tokenApprovals[_requestId] == msgSender)
        ) {
            revert NotOwnerOrApproved(msgSender);
        }

        delete _tokenApprovals[_requestId];
        request.owner = _to;

        assert(_requestsByOwner[_from].remove(_requestId));
        assert(_requestsByOwner[_to].add(_requestId));

        _emitTransfer(_from, _to, _requestId);
    }

    /// @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
    /// The call is not executed if the target address is not a contract.
    ///
    /// @param _from address representing the previous owner of the given token ID
    /// @param _to target address that will receive the tokens
    /// @param _requestId uint256 ID of the token to be transferred
    /// @param _data bytes optional data to send along with the call
    /// @return bool whether the call correctly returned the expected magic value
    function _checkOnERC721Received(
        address _from,
        address _to,
        uint256 _requestId,
        bytes memory _data
    ) private returns (bool) {
        if (_to.isContract()) {
            try
                IERC721Receiver(_to).onERC721Received(
                    msg.sender,
                    _from,
                    _requestId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert TransferToNonIERC721Receiver(_to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    //
    // Internal getters and setters
    //

    /// @dev a little crutch to emit { Transfer } on request and on claim like ERC721 states
    function _emitTransfer(
        address _from,
        address _to,
        uint256 _requestId
    ) internal override {
        emit Transfer(_from, _to, _requestId);
    }

    /// @dev Returns whether `_requestId` exists and not claimed.
    function _existsAndNotClaimed(
        uint256 _requestId
    ) internal view returns (bool) {
        return
            _requestId > 0 &&
            _requestId <= getLastRequestId() &&
            !_queue[_requestId].claimed;
    }

    /// @dev Approve `_to` to operate on `_requestId`
    /// Emits a { Approval } event.
    function _approve(address _to, uint256 _requestId) internal {
        _tokenApprovals[_requestId] = _to;
        emit Approval(ownerOf(_requestId), _to, _requestId);
    }

    /// @dev Approve `operator` to operate on all of `owner` tokens
    /// Emits a { ApprovalForAll } event.
    function _setApprovalForAll(
        address _owner,
        address _operator,
        bool _approved
    ) internal {
        if (_owner == _operator) revert ApproveToCaller();
        _operatorApprovals[_owner][_operator] = _approved;
        emit ApprovalForAll(_owner, _operator, _approved);
    }

    /// @dev Decode a `bytes32 to string
    function _toString(bytes32 _sstr) internal pure returns (string memory) {
        uint256 len = _length(_sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), _sstr)
        }
        return str;
    }

    /// @dev encodes string `_str` in bytes32. Reverts if the string length > 31
    function _toBytes32(string memory _str) internal pure returns (bytes32) {
        bytes memory bstr = bytes(_str);
        if (bstr.length > 31) {
            revert StringTooLong(_str);
        }
        return bytes32(uint256(bytes32(bstr)) | bstr.length);
    }

    /// @dev Return the length of a string encoded in bytes32
    function _length(bytes32 _sstr) internal pure returns (uint256) {
        return uint256(_sstr) & 0xFF;
    }

    function _constructTokenUri(
        uint256 _requestId
    ) internal view returns (string memory) {
        string memory baseURI = _baseURI.value;
        if (bytes(baseURI).length == 0) return "";

        // ${baseUri}/${_requestId}?requested=${amount}&created_at=${timestamp}[&finalized=${claimableAmount}]
        string memory uri = string(
            // we have no string.concat in 0.8.9 yet, so we have to do it with bytes.concat
            bytes.concat(
                bytes(baseURI),
                bytes("/"),
                bytes(_requestId.toString()),
                bytes("?requested="),
                bytes(
                    uint256(
                        _queue[_requestId].cumulativeStUSD -
                            _queue[_requestId - 1].cumulativeStUSD
                    ).toString()
                ),
                bytes("&created_at="),
                bytes(uint256(_queue[_requestId].timestamp).toString())
            )
        );
        bool finalized = _requestId <= getLastFinalizedRequestId();

        if (finalized) {
            uri = string(
                bytes.concat(
                    bytes(uri),
                    bytes("&finalized="),
                    bytes(
                        _getClaimableUsd(
                            _requestId,
                            _findCheckpointHint(
                                _requestId,
                                1,
                                getLastCheckpointIndex()
                            )
                        ).toString()
                    )
                )
            );
        }

        return uri;
    }
}
