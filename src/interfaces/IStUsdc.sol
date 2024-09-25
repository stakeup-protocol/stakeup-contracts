// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";

import {IStakeUpStaking} from "./IStakeUpStaking.sol";
import {IStakeUpToken} from "./IStakeUpToken.sol";
import {IStUsdcLite} from "./IStUsdcLite.sol";
import {IWstUsdc} from "./IWstUsdc.sol";
import {ILayerZeroSettings} from "./ILayerZeroSettings.sol";

interface IStUsdc is IStUsdcLite, ILayerZeroSettings {
    // =================== Events ===================

    /**
     * @notice Emitted when LP tokens are redeemed
     * @param account Redeeming account
     * @param shares Amount of LP tokens burned
     * @param amount Amount of underlying tokens paid out to the user
     */
    event Redeemed(address indexed account, uint256 shares, uint256 amount);

    /**
     * @notice Emitted when the underlying asset is auto lent into a Bloom Pool
     * @param amount Amount of USDC lent
     */
    event AssetAutoLent(uint256 amount);

    /**
     * @notice Emitted when someone corrects the remaining balance
     * using the poke function
     * @param amount The updated remaining balance
     */
    event RemainingBalanceAdjusted(uint256 amount);

    /**
     * @notice Emitted when a fee is captured and sent to the StakeUp Staking
     * @param shares Number of stUsdc shares sent to the StakeUp Staking
     */
    event FeeCaptured(uint256 shares);

    /**
     * @notice Emitted when user deposits underlying assets into stUSDC
     * @param account User address
     * @param amount Amount of tokens deposited
     */
    event AssetDeposited(address indexed account, uint256 amount);

    /**
     * @notice Emitted when a TBY is deposited into stUSDC
     * @param account User address
     * @param tbyId The tokenID of a TBY
     * @param amount TBY amount to deposit
     * @param stUsdcAmount Amount of stUSDC minted
     */
    event TbyDeposited(address indexed account, uint256 indexed tbyId, uint256 amount, uint256 stUsdcAmount);

    /**
     * @notice Deposit TBY and get stUsdc minted
     * @dev TBY deposits are eligible for additional mint rewards
     * @param tbyId The tokenID of a TBY
     * @param amount TBY amount to deposit
     * @return amountMinted Amount of stUsdc minted
     */
    function depositTby(uint256 tbyId, uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Deposit underlying assets to mint stUsdc
     * @param amount Amount of underlying tokens to deposit
     * @return amountMinted Amount of stUsdc minted
     */
    function depositAsset(uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Redeem stUsdc in exchange for underlying tokens. Underlying
     * tokens.
     * @dev Emits a {Redeemed} event.
     * @param amount Amount of stUsdc to redeem
     * @return underlyingAmount The Amount of underlying tokens redeemed
     */
    function redeemStUsdc(uint256 amount) external returns (uint256 underlyingAmount);

    /**
     * @notice Invokes the auto stake feature or adjusts the remaining balance
     * if the most recent deposit did not get fully staked
     * @dev autoMint feature is invoked if the last created pool is in
     * the commit state
     * @dev Sends a messages to all LayerZero peers to update _rewardPerSecond
     */
    function poke(LzSettings calldata settings) external payable;

    /// @notice Returns the underlying asset
    function asset() external view returns (IERC20);

    /// @notice Returns the address of the TBY token
    function tby() external view returns (ERC1155);

    /// @notice Returns the Bloom Pool Factory
    function bloomPool() external view returns (IBloomPool);

    /// @notice Returns the WstUsdc contract
    function wstUsdc() external view returns (IWstUsdc);

    /// @notice Returns the StakeUpStaking contract.
    function stakeUpStaking() external view returns (IStakeUpStaking);

    /// @notice Returns the StakeUpToken contract.
    function stakeUpToken() external view returns (IStakeUpToken);

    /// @notice Returns the performanceBps.
    function performanceBps() external view returns (uint256);

    /// @notice Returns the last redeemed TbyId.
    function lastRedeemedTbyId() external view returns (uint256);

    /// @notice The total shares of stUsdc tokens in circulation on all chains
    function globalShares() external view returns (uint256);

    /// @notice The last time the rate was updated
    function lastRateUpdate() external view returns (uint256);

    /// @notice The pending fee to be captured during the next poke
    function pendingFee() external view returns (uint256);
}
