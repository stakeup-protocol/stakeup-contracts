// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";
import {OFTController} from "@StakeUp/messaging/controllers/OFTController.sol";
import {IRebasingOFT} from "@StakeUp/interfaces/IRebasingOFT.sol";

abstract contract RebasingOFT is IRebasingOFT, OFTController {
    using FpMath for uint256;

    // =================== Storage ===================
    /// @dev Mapping of account addresses to their corresponding shares
    mapping(address => uint256) internal _shares;

    /// @dev Total amount of shares
    uint256 internal _totalShares;

    // =================== Constructor ===================
    constructor(string memory name_, string memory symbol_, address layerZeroEndpoint_, address bridgeOperator_)
        OFTController(name_, symbol_, layerZeroEndpoint_, bridgeOperator_)
    {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== External Functions =====================
    /// @inheritdoc IRebasingOFT
    function transferShares(address recipient, uint256 sharesAmount) external returns (uint256) {
        _transferShares(msg.sender, recipient, sharesAmount);
        uint256 tokensAmount = _amountByShares(sharesAmount);
        _emitTransferEvents(msg.sender, recipient, tokensAmount, sharesAmount);
        return tokensAmount;
    }

    /// @inheritdoc IRebasingOFT
    function transferSharesFrom(address sender, address recipient, uint256 sharesAmount) external returns (uint256) {
        uint256 tokensAmount = _amountByShares(sharesAmount);
        _spendAllowance(sender, msg.sender, tokensAmount);
        _transferShares(sender, recipient, sharesAmount);
        _emitTransferEvents(sender, recipient, tokensAmount, sharesAmount);
        return tokensAmount;
    }

    // =================== Internal Functions =====================

    /// @notice Internal logic for transferring tokens
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        uint256 sharesToTransfer = _sharesByAmount(amount);
        _transferShares(sender, recipient, sharesToTransfer);
        _emitTransferEvents(sender, recipient, amount, sharesToTransfer);
    }

    /// @notice Internal logic for transferring shares
    function _transferShares(address sender, address recipient, uint256 sharesAmount) internal {
        require(sender != address(0), Errors.ZeroAddress());
        require(recipient != address(0), Errors.ZeroAddress());

        uint256 currentSenderShares = _shares[sender];
        require(sharesAmount <= currentSenderShares, Errors.InsufficientBalance());

        _shares[sender] = currentSenderShares - sharesAmount;
        _shares[recipient] = _shares[recipient] + sharesAmount;
    }

    /**
     * @notice  Creates `sharesAmount` shares and assigns them to `recipient`, increasing the total amount of shares.
     * @dev This doesn't increase the token total supply.
     * Requirements:
     * - `recipient` cannot be the zero address.
     * @param recipient Destination where minted shares will be sent
     * @param sharesAmount Amount of shares to mint
     */
    function _mintShares(address recipient, uint256 sharesAmount) internal virtual returns (uint256 newTotalShares) {
        require(recipient != address(0), Errors.ZeroAddress());

        newTotalShares = _totalShares + sharesAmount;
        _totalShares = newTotalShares;

        _shares[recipient] = _shares[recipient] + sharesAmount;
        _emitTransferEvents(address(0), recipient, _amountByShares(sharesAmount), sharesAmount);
    }

    /**
     * @notice Destroys `sharesAmount` shares from `account`'s holdings, decreasing the total amount of shares.
     * @dev This doesn't decrease the token total supply.
     *  Requirements:
     * - `account` cannot be the zero address.
     * - `account` must hold at least `sharesAmount` shares.
     * @param account Account to burn shares from
     * @param sharesAmount Amount of shares to burn
     */
    function _burnShares(address account, uint256 sharesAmount) internal virtual returns (uint256 newTotalShares) {
        require(account != address(0), Errors.ZeroAddress());

        uint256 accountShares = _shares[account];
        require(sharesAmount <= accountShares, Errors.InsufficientBalance());

        uint256 preRebaseTokenAmount = _amountByShares(sharesAmount);

        newTotalShares = _totalShares - sharesAmount;
        _totalShares = newTotalShares;

        _shares[account] = accountShares - sharesAmount;

        uint256 postRebaseTokenAmount = _amountByShares(sharesAmount);

        _emitTransferEvents(account, address(0), postRebaseTokenAmount, sharesAmount);
    }

    /// @notice Get the amount of tokens that is equivalent to a specified amount of shares
    function _amountByShares(uint256 sharesAmount) internal view returns (uint256) {
        uint256 totalShares_ = _totalShares;
        if (totalShares_ == 0) {
            return sharesAmount;
        }
        return sharesAmount.mulWad(_totalSupply()).divWad(totalShares_);
    }

    /// @notice Get the amount of shares that is equivalent to a specified amount of tokens
    function _sharesByAmount(uint256 amount) internal view returns (uint256) {
        uint256 totalShares_ = _totalShares;
        uint256 totalUsd_ = _totalSupply();

        if (totalShares_ == 0) {
            return amount;
        }
        if (totalUsd_ == 0) {
            return totalShares_;
        }

        return amount.mulWad(totalShares_).divWad(totalUsd_);
    }

    /// @dev Emits {Transfer} and {TransferShares} events
    function _emitTransferEvents(address from, address to, uint256 tokenAmount, uint256 sharesAmount) internal {
        emit Transfer(from, to, tokenAmount);
        emit TransferShares(from, to, sharesAmount);
    }

    // =================== View Functions =====================
    /// @inheritdoc IRebasingOFT
    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    /// @inheritdoc IRebasingOFT
    function sharesOf(address account) external view returns (uint256) {
        return _shares[account];
    }

    /// @inheritdoc ERC20
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply();
    }

    /// @inheritdoc ERC20
    function balanceOf(address account) public view override returns (uint256) {
        return _amountByShares(_shares[account]);
    }

    // =================== LayerZero Functions =====================

    function _debit(uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // Implement in child contract
    }

    function _credit(address _to, uint256 _amountToCreditLD, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        // Implement in child contract
    }

    // =================== Virtual Functions =====================
    /**
     * @notice Gets the total Supply of the token
     * @return The total Supply
     */
    function _totalSupply() internal view virtual returns (uint256);
}
