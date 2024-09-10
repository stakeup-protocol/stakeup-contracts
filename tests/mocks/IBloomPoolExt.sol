// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

// Interface that contains functions that are used for the owner and permissioned users of the pool, along with all
//      functions that are within IBloomPool
interface IBloomPoolExt is IBloomPool {
    // ===================== Permissioned Functions ====================
    /**
     * @notice Swaps in assets for rwa tokens, starting the TBY minting process.
     * @dev Only market makers can call this function.
     * @dev From the first swap for a given TBY id, the market maker has 48 hours to fill orders that
     *      will be included in the batch. All TBYs will mature after 180 days.
     * @param accounts An Array of addresses to convert from matched orders to live TBYs.
     * @param assetAmount The amount of assets that will be swapped out for rwa tokens.
     * @return id The id of the TBY that was minted.
     * @return amountSwapped The amount of assets swapped in.
     */
    function swapIn(address[] memory accounts, uint256 assetAmount)
        external
        returns (uint256 id, uint256 amountSwapped);

    /**
     * @notice Swaps asset tokens in and rwa tokens out, ending the TBY life cycle.
     * @dev Only market makers can call this function.
     * @dev Can only be called after the TBY has matured.
     * @param id The id of the TBY that the swap is for.
     * @param rwaAmount The amount of rwa tokens to remove.
     * @return assetAmount The amount of assets swapped out.
     */
    function swapOut(uint256 id, uint256 rwaAmount) external returns (uint256 assetAmount);

    // ======================== Owner Functions ========================
    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     * @param isKyced True to whitelist, false to remove from whitelist.
     */
    function whitelistBorrower(address account, bool isKyced) external;

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     * @param isKyced True to whitelist, false to remove from whitelist.
     */
    function whitelistMarketMaker(address account, bool isKyced) external;

    /**
     * @notice Updates the leverage for future borrower fills
     * @dev Leverage is scaled to 1e18. (20x leverage = 20e18)
     * @param leverage Updated leverage
     */
    function setLeverage(uint256 leverage) external;

    /**
     * @notice Updates the spread between the TBY rate and the RWA rate.
     * @param spread_ The new spread value.
     */
    function setSpread(uint256 spread_) external;

    /**
     * @notice Sets the length of time that future TBY Ids will mature for.
     * @param maturity The length of time that future TBYs Id will mature for.
     */
    function setMaturity(uint256 maturity) external;

    /**
     * @notice Sets the price feed for the RWA token.
     * @dev Only the owner can call this function.
     * @param rwaPriceFeed_ The address of the price feed for the RWA token.
     */
    function setPriceFeed(address rwaPriceFeed_) external;
}
