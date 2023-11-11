// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRedemptionNFT {
    
    /// @notice Reverts if the caller is not the stUSD contract
    error CallerNotStUSD();

    /// @notice Reverts if the caller is not the owner of the NFT
    error NotOwner();

    /// @notice Reverts if the withdrawal request has already been claimed
    error RedemptionClaimed();

    /**
     * @notice A Struct that represents a users withdrawal request
     * @param amountOfShares the amount of stUSD shares that have been submitted for this request
     * @param owner Address that can claim, cancel, or transfer the request
     * @param timestamp Timestamp of when the request was made
     * @param claimed Whether or not the request has been claimed
     */
    struct WithdrawalRequest {
        uint256 amountOfShares;
        address owner;
        uint40 timestamp;
        bool claimed;
    }

    function addWithdrawalRequest(address to, uint256 shares) external returns (uint256);

    function claimWithdrawal(uint256 tokenId) external;

    function getWithdrawalRequest(uint256 tokenId) external view returns (WithdrawalRequest memory);
}