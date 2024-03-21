import "./ERC721/ERC721_RedemptionNFT.spec";
import "./ILayerZeroEndpoint.spec";

//////////////////// USING ////////////////////////

using RedemptionNFTHarness as _RedemptionNFT;

/////////////////// METHODS ///////////////////////

methods {
    // RedemptionNFTHarness
    function _RedemptionNFT.decodePayload(bytes _payload) external returns (address, uint256[], uint256[]) envfree;

    // RedemptionNFT
    function _RedemptionNFT.addWithdrawalRequest(address to, uint256 shares) external returns (uint256);
    function _RedemptionNFT.claimWithdrawal(uint256 tokenId) external;
    function _RedemptionNFT.clearCredits(bytes _payload) external;
    function _RedemptionNFT.getWithdrawalRequest(uint256 tokenId) external returns (IRedemptionNFT.WithdrawalRequest) envfree;
    function _RedemptionNFT.getStTBY() external returns (address) envfree;
}

////////////////// FUNCTIONS //////////////////////

function init_RedemptionNFT(env e) {
    requireInvariant mintedNFTCorrespondsWithdrawalRequest;
    requireInvariant mintCountMonotonicallyIncreasing;
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `uint256 private _mintCount;`
//

ghost mathint ghostMintCount {
    init_state axiom ghostMintCount == 0;
    axiom ghostMintCount >= 0 && ghostMintCount <= max_uint256;
}

ghost mathint ghostMintCountPrev {
    init_state axiom ghostMintCountPrev == 0;
    axiom ghostMintCountPrev >= 0 && ghostMintCountPrev <= max_uint256;
}

hook Sload uint256 val _RedemptionNFT._mintCount STORAGE {
    require(require_uint256(ghostMintCount) == val);
}

hook Sstore _RedemptionNFT._mintCount uint256 val (uint256 valPrev) STORAGE {
    ghostMintCountPrev = valPrev;
    ghostMintCount = val;
}

//
// Ghost copy of `mapping(uint256 => WithdrawalRequest) private _withdrawalRequests;`
//

// uint256 amountOfShares;

ghost mapping (mathint => mathint) ghostWRAmountOfShares {
    init_state axiom forall uint256 i. ghostWRAmountOfShares[i] == 0;
    axiom forall uint256 i. ghostWRAmountOfShares[i] >= 0 && ghostWRAmountOfShares[i] <= max_uint256;
}

ghost mapping (mathint => mathint) ghostWRAmountOfSharesPrev {
    init_state axiom forall uint256 i. ghostWRAmountOfSharesPrev[i] == 0;
    axiom forall uint256 i. ghostWRAmountOfSharesPrev[i] >= 0 && ghostWRAmountOfSharesPrev[i] <= max_uint256;
}

hook Sload uint256 val _RedemptionNFT._withdrawalRequests[KEY uint256 i].amountOfShares STORAGE {
    require(require_uint256(ghostWRAmountOfShares[i]) == val);
} 

hook Sstore _RedemptionNFT._withdrawalRequests[KEY uint256 i].amountOfShares uint256 val (uint256 valPrev) STORAGE {
    ghostWRAmountOfSharesPrev[i] = valPrev;
    ghostWRAmountOfShares[i] = val;
}

// address owner;

ghost mapping (mathint => address) ghostWROwner {
    init_state axiom forall mathint i. ghostWROwner[i] == 0;
}

ghost mapping (mathint => address) ghostWROwnerPrev {
    init_state axiom forall mathint i. ghostWROwnerPrev[i] == 0;
}

hook Sload address val _RedemptionNFT._withdrawalRequests[KEY uint256 i].owner STORAGE {
    require(ghostWROwner[i] == val);
} 

hook Sstore _RedemptionNFT._withdrawalRequests[KEY uint256 i].owner address val (address valPrev) STORAGE {
    ghostWROwnerPrev[i] = valPrev;
    ghostWROwner[i] = val;
}

// bool claimed;

ghost mapping (mathint => bool) ghostWRClaimed {
    init_state axiom forall uint256 i. ghostWRClaimed[i] == false;
}

ghost mapping (mathint => bool) ghostWRClaimedPrev {
    init_state axiom forall uint256 i. ghostWRClaimedPrev[i] == false;
}

hook Sload bool val _RedemptionNFT._withdrawalRequests[KEY uint256 i].claimed STORAGE {
    require(ghostWRClaimed[i] == val);
} 

hook Sstore _RedemptionNFT._withdrawalRequests[KEY uint256 i].claimed bool val (bool valPrev) STORAGE {
    ghostWRClaimedPrev[i] = valPrev;
    ghostWRClaimed[i] = val;
}

///////////////// PROPERTIES //////////////////////

// NFT-01 _mintCount is monotonically increasing
invariant mintCountMonotonicallyIncreasing() ghostMintCount == 0 || ghostMintCount == ghostMintCountPrev + 1;

// NFT-02 The owner of the NFT must match the owner in the withdrawal request
invariant mintedNFTCorrespondsWithdrawalRequest() 
    forall mathint tokenId. ghostWROwner[tokenId] == ghostErc721Owners_RedemptionNFT[tokenId];