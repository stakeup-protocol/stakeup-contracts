// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

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
        bool claimed;
    }

    /**
     * @notice Mints a new NFT and adds a withdrawal request
     * @dev This function is callable by the stUSD contract only
     * @param to Recipient of the withdrawal request
     * @param shares Shares requested to be withdrawn
     */
    function addWithdrawalRequest(address to, uint256 shares) external returns (uint256);

    /**
     * @notice Claims a withdrawal request in exchange for underlying tokens
     * @param tokenId The tokenId of the NFT
     */
    function claimWithdrawal(uint256 tokenId) external;

    /**
     * @notice Returns the withdrawal request for a given tokenId
     * @param tokenId The tokenId of the NFT
     */
    function getWithdrawalRequest(uint256 tokenId) external view returns (WithdrawalRequest memory);

    /**
     * @notice Returns the address of the stUSD contract
     */
    function getStUSD() external view returns (address);
}