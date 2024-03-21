using RedemptionNFTHarness as _ERC721_RedemptionNFT;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC721_RedemptionNFT.supportsInterface(bytes4 interfaceId) external returns (bool) => NONDET DELETE;
    function _ERC721_RedemptionNFT.balanceOf(address owner) external returns (uint256) envfree;
    function _ERC721_RedemptionNFT.ownerOf(uint256 tokenId) external returns (address) envfree;
    function _ERC721_RedemptionNFT.name() external returns (string) envfree;
    function _ERC721_RedemptionNFT.symbol() external returns (string) envfree;
    function _ERC721_RedemptionNFT.tokenURI(uint256 tokenId) external returns (string) envfree;
    function _ERC721_RedemptionNFT.approve(address to, uint256 tokenId) external;
    function _ERC721_RedemptionNFT.getApproved(uint256 tokenId) external returns (address) envfree;
    function _ERC721_RedemptionNFT.setApprovalForAll(address operator, bool approved) external;
    function _ERC721_RedemptionNFT.isApprovedForAll(address owner, address operator) external returns (bool) envfree;
    function _ERC721_RedemptionNFT.transferFrom(address from, address to, uint256 tokenId) external;
    function _ERC721_RedemptionNFT.safeTransferFrom(address from, address to, uint256 tokenId) external;
    function _ERC721_RedemptionNFT.safeTransferFrom(address from, address to, uint256 tokenId, bytes data) external;

    function ERC721._checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) internal returns (bool)
        => ALWAYS(true);

    // Always return `IERC721Receiver.onERC721Received.selector`
    function _.onERC721Received(address operator, address from, uint256 tokenId, bytes data) external
        => ALWAYS(0x150b7a02); 
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `mapping(uint256 => address) private _owners;`
//

ghost mapping (mathint => address) ghostErc721Owners_RedemptionNFT {
    init_state axiom forall mathint i. ghostErc721Owners_RedemptionNFT[i] == 0;
}

ghost mapping (mathint => address) ghostErc721OwnersPrev_RedemptionNFT {
    init_state axiom forall mathint i. ghostErc721OwnersPrev_RedemptionNFT[i] == 0;
}

hook Sload address val _ERC721_RedemptionNFT._owners[KEY uint256 i] STORAGE {
    require(ghostErc721Owners_RedemptionNFT[i] == val);
} 

hook Sstore _ERC721_RedemptionNFT._owners[KEY uint256 i] address val (address valPrev) STORAGE {
    ghostErc721OwnersPrev_RedemptionNFT[i] = valPrev;
    ghostErc721Owners_RedemptionNFT[i] = val;
}

//
// Ghost copy of `mapping(address => uint256) private _balances`
//

ghost mapping (address => mathint) ghostErc721Balances_RedemptionNFT {
    init_state axiom forall address i. ghostErc721Balances_RedemptionNFT[i] == 0;
    axiom forall address i. ghostErc721Balances_RedemptionNFT[i] >= 0 && ghostErc721Balances_RedemptionNFT[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostErc721BalancesPrev_RedemptionNFT {
    init_state axiom forall address i. ghostErc721BalancesPrev_RedemptionNFT[i] == 0;
    axiom forall address i. ghostErc721BalancesPrev_RedemptionNFT[i] >= 0 && ghostErc721BalancesPrev_RedemptionNFT[i] <= max_uint256;
}

ghost mathint ghostErc721SumAllBalance_RedemptionNFT {
    init_state axiom ghostErc721SumAllBalance_RedemptionNFT == 0;
    axiom ghostErc721SumAllBalance_RedemptionNFT >= 0 && ghostErc721SumAllBalance_RedemptionNFT <= max_uint256;
}

ghost address ghostErc721UserInit_RedemptionNFT {
    init_state axiom ghostErc721UserInit_RedemptionNFT == 0;
}

hook Sload uint256 val _ERC721_RedemptionNFT._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc721Balances_RedemptionNFT[i]) == val);
} 

hook Sstore _ERC721_RedemptionNFT._balances[KEY address i] uint256 val STORAGE {
    ghostErc721BalancesPrev_RedemptionNFT[i] = ghostErc721Balances_RedemptionNFT[i];
    ghostErc721Balances_RedemptionNFT[i] = val;
    ghostErc721SumAllBalance_RedemptionNFT = ghostErc721SumAllBalance_RedemptionNFT + val - ghostErc721BalancesPrev_RedemptionNFT[i];
}

//
// Ghost copy of `mapping(uint256 => address) private _tokenApprovals;`
//

ghost mapping (mathint => address) ghostErc721TokenApprovals_RedemptionNFT {
    init_state axiom forall mathint i. ghostErc721TokenApprovals_RedemptionNFT[i] == 0;
}

hook Sload address val _ERC721_RedemptionNFT._tokenApprovals[KEY uint256 i] STORAGE {
    require(ghostErc721TokenApprovals_RedemptionNFT[i] == val);
} 

hook Sstore _ERC721_RedemptionNFT._tokenApprovals[KEY uint256 i] address val STORAGE {
    ghostErc721TokenApprovals_RedemptionNFT[i] = val;
}

//
// Ghost copy of `mapping(address => mapping(address => bool)) private _operatorApprovals;`
//

ghost mapping(address => mapping(address => bool)) ghostErc721OperatorApprovals_RedemptionNFT {
    init_state axiom forall address key. forall address val. ghostErc721OperatorApprovals_RedemptionNFT[key][val] == false;
}

ghost mapping(address => mapping(address => bool)) ghostErc721OperatorApprovalsPrev_RedemptionNFT {
    init_state axiom forall address key. forall address val. ghostErc721OperatorApprovalsPrev_RedemptionNFT[key][val] == false;
}

hook Sload bool isApprove _ERC721_RedemptionNFT._operatorApprovals[KEY address owner][KEY address operator] STORAGE {
    require(ghostErc721OperatorApprovals_RedemptionNFT[owner][operator] == isApprove);
}

hook Sstore _ERC721_RedemptionNFT._operatorApprovals[KEY address owner][KEY address operator] bool isApprove (bool isApprovePrev) STORAGE {
    ghostErc721OperatorApprovals_RedemptionNFT[owner][operator] = isApprovePrev;
    ghostErc721OperatorApprovals_RedemptionNFT[owner][operator] = isApprove;
}
