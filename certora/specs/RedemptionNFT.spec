import "./base/_RedemptionNFT.spec";
import "./base/_StTBY.spec";
import "./base/ERC20/ERC20_StableTokenMockERC20.spec";
import "./base/ONFT721.spec";

///////////////// DEFINITIONS /////////////////////

definition IS_TRANSFERED(address ownerBefore, address ownerAfter) returns bool =
    ownerBefore != ownerAfter && ownerAfter != 0;

definition TRANSFER_FUNCTIONS(method f) returns bool =
    f.selector == sig:safeTransferFrom(address,address,uint256).selector
    || f.selector == sig:safeTransferFrom(address,address,uint256,bytes).selector
    || f.selector == sig:transferFrom(address,address,uint256).selector;

///////////////// GHOSTS & HOOKS //////////////////

hook CHAINID uint id {
    require(id == 1);
}

///////////////// PROPERTIES //////////////////////

use builtin rule sanity; 

// RedemptionNFT valid state
use invariant mintedNFTCorrespondsWithdrawalRequest;
use invariant mintCountMonotonicallyIncreasing;

// NFT-03 Each newly minted NFT must have a unique token ID

rule mintedNFTUniqId(env e1, env e2, calldataarg args1, calldataarg args2) {

    mathint id1 = addWithdrawalRequest(e1, args1);

    mathint id2 = addWithdrawalRequest(e2, args2);

    assert(id1 != id2);
}

rule mintedNFTUniqIdPossibility(env e1, env e2, calldataarg args1, calldataarg args2) {

    mathint id1 = addWithdrawalRequest@withrevert(e1, args1);
    bool reverted1 = lastReverted;

    mathint id2 = addWithdrawalRequest@withrevert(e2, args2);
    bool reverted2 = lastReverted;

    satisfy(!reverted1 && !reverted2 && id1 != id2);
}

// NFT-04 After burn NFT, withdrawal request gets empty
rule afterBurnNFTWithdrawalRequestCleared(env e, method f, calldataarg args) {

    require(forall mathint id. ghostErc721Owners_RedemptionNFT[id] == ghostErc721OwnersPrev_RedemptionNFT[id]);

    f(e, args);

    assert(forall mathint id1. forall mathint id2. 
        // Owner of NFT changed to zero (mean burnt)
        id1 != id2 && ghostErc721Owners_RedemptionNFT[id1] != ghostErc721OwnersPrev_RedemptionNFT[id1] 
            && ghostErc721Owners_RedemptionNFT[id1] == 0
        // NFT's withdrawal request is cleared
        => (ghostWRAmountOfShares[id1] == 0 && ghostWROwner[id1] == 0 && ghostWRClaimed[id1] == false)
    );
}

// NFT-05 After a LayerZero receive NFT supply is incremented by length of tokenIds array
rule supplyIncrementedWhenLayerZeroReceive(env e, uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) {
    
    address toAddress;
    uint256[] tokenIds; 
    uint256[] amountOfShares;
    toAddress, tokenIds, amountOfShares = decodePayload(_payload);
    require(tokenIds.length <= 2);
    require(amountOfShares.length <= 2);

    bytes32 hashedPayload = keccak256(_payload);
    require(ghostStoredCreditsIndex[hashedPayload] == 0);

    mathint balanceBefore = ghostErc721Balances_RedemptionNFT[toAddress];

    nonblockingLzReceive(e, _srcChainId, _srcAddress, _nonce, _payload);

    mathint minted = ghostErc721Balances_RedemptionNFT[toAddress] - balanceBefore;
    mathint stored = to_mathint(tokenIds.length) - ghostStoredCreditsIndex[hashedPayload];

    assert(minted + stored == to_mathint(tokenIds.length));
}

// NFT-06 Withdrawal requests can only be claimed once
rule withdrawalRequestsCanOnlyClaimedOnce(env e1, env e2, uint256 tokenId) {

    claimWithdrawal(e1, tokenId);
    bool reverted1 = lastReverted;

    claimWithdrawal@withrevert(e2, tokenId);
    bool reverted2 = lastReverted;

    assert(!reverted1 => reverted2);
}

// NFT-07 On claim withdrawal shares must be withdrawn from the stTBY contract to the NFT owner's address
rule claimWithdrawalTransferStTBYToOwner(env e, calldataarg args) {

    init_StTBY(e);
    init_ERC20_StableToken();

    mathint balanceBefore = ghostErc20Balances_StableToken[e.msg.sender];
    require(balanceBefore == 0);

    claimWithdrawal(e, args);

    mathint balanceAfter = ghostErc20Balances_StableToken[e.msg.sender];

    // Possibility of increase sender's StTBY balance
    satisfy(balanceAfter > balanceBefore);
}

// NFT-08 Only the StTBY contract or LzApp can initiate the minting of a RedemptionNFT
rule onlyStTBYorLzAppCanMint(env e, method f, calldataarg args) 
    // Public function for anyone to clear and deliver the remaining batch sent tokenIds 
    filtered { f -> f.selector != sig:clearCredits(bytes).selector } {

    address lzApp = lzEndpoint();
    require(forall mathint id. ghostErc721Owners_RedemptionNFT[id] == ghostErc721OwnersPrev_RedemptionNFT[id]);

    f(e, args);

    // New owner set
    assert(forall mathint id. ghostErc721Owners_RedemptionNFT[id] != ghostErc721OwnersPrev_RedemptionNFT[id] 
        // No owner set previously
        && ghostErc721OwnersPrev_RedemptionNFT[id] == 0 => (
            // StTBY
            e.msg.sender == _StTBY 
            // LzApp
            || e.msg.sender == currentContract || e.msg.sender == lzApp
        )
    );
}

// NFT-09 NFTs associated with unclaimed withdrawal requests could be transferred
rule unclaimedWithdrawalRequestsTransferNFTPossibility(env e, method f, calldataarg args, mathint tokenId) 
    filtered { f -> TRANSFER_FUNCTIONS(f) } {

    // Do not assume mint
    address ownerBefore = ghostErc721Owners_RedemptionNFT[tokenId];
    require(ownerBefore != 0);

    bool claimed = ghostWRClaimed[tokenId];
    require(!claimed);

    f@withrevert(e, args);
    bool reverted = lastReverted;

    address ownerAfter = ghostErc721Owners_RedemptionNFT[tokenId];

    // Possibility of transfer
    satisfy(!reverted && IS_TRANSFERED(ownerBefore, ownerAfter));
}

// NFT-10 Only the request owner can transfer the corresponding NFT
rule ownlyRequestOwerCanTransferNFT(env e, method f, calldataarg args, mathint tokenId) {

    // Do not assume mint
    address ownerBefore = ghostErc721Owners_RedemptionNFT[tokenId];
    require(ownerBefore != 0);

    address requestOwner = ghostWROwner[tokenId];
    address approvedOwner = ghostErc721TokenApprovals_RedemptionNFT[tokenId];
    bool senderAsOperatorApproved = ghostErc721OperatorApprovals_RedemptionNFT[ownerBefore][e.msg.sender];

    f(e, args);

    address ownerAfter = ghostErc721Owners_RedemptionNFT[tokenId];

    // NFT transfered
    assert(IS_TRANSFERED(ownerBefore, ownerAfter) => (
        // Owner of transfered NFT should be the same as withdraw request
        ownerBefore == requestOwner
        // Owner or approved user can initialize a transaction
        && (e.msg.sender == ownerBefore || e.msg.sender == approvedOwner || senderAsOperatorApproved)
        )
    );
}