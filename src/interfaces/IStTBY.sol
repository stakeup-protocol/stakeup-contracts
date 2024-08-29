// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBloomFactory} from "./bloom/IBloomFactory.sol";
import {IExchangeRateRegistry} from "./bloom/IExchangeRateRegistry.sol";
import {IStakeUpStaking} from "./IStakeUpStaking.sol";
import {IStTBYBase} from "./IStTBYBase.sol";
import {IWstTBY} from "./IWstTBY.sol";

interface IStTBY is IStTBYBase {
    // =================== Events ===================

    /**
     * @notice Emitted when LP tokens are redeemed
     * @param account Redeeming account
     * @param shares Amount of LP tokens burned
     * @param amount Amount of underlying tokens paid out to the user
     */
    event Redeemed(address indexed account, uint256 shares, uint256 amount);

    /**
     * @notice Emitted when USDC is deposited into a Bloom Pool
     * @param tby TBY address
     * @param amount Amount of TBY deposited
     */
    event TBYAutoMinted(address indexed tby, uint256 amount);

    /**
     * @notice Emitted when someone corrects the remaining balance
     * using the poke function
     * @param amount The updated remaining balance
     */
    event RemainingBalanceAdjusted(uint256 amount);

    /**
     * @notice Emitted when a fee is captured and sent to the StakeUp Staking
     * @param shares Number of stTBY shares sent to the StakeUp Staking
     */
    event FeeCaptured(uint256 shares);

    /**
     * @notice Emitted when user deposits
     * @param account User address
     * @param token Address of the token being deposited
     * @param amount Amount of tokens deposited
     * @param shares Amount of shares minted to the user
     */
    event Deposit(address indexed account, address token, uint256 amount, uint256 shares);

    /**
     * @notice Deposit TBY and get stTBY minted
     * @param tby TBY address
     * @param amount TBY amount to deposit
     * @return amountMinted Amount of stTBY minted
     */
    function depositTby(address tby, uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Deposit underlying tokens and get stTBY minted
     * @param amount Amount of underlying tokens to deposit
     * @return amountMinted Amount of stTBY minted
     */
    function depositUnderlying(uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Redeem stTBY in exchange for underlying tokens. Underlying
     * tokens.
     * @dev Emits a {Redeemed} event.
     * @param amount Amount of stTBY to redeem
     * @return underlyingAmount The Amount of underlying tokens redeemed
     */
    function redeemStTBY(uint256 amount) external returns (uint256 underlyingAmount);

    /**
     * @notice Redeems the underlying token from a Bloom Pool in exchange for TBYs
     * @dev Underlying tokens can only be redeemed if stTBY contains a TBY which is
     *     in its FinalWithdrawal state.
     * @param tby TBY address
     */
    function harvestTBY(address tby) external;

    /**
     * @notice Invokes the auto stake feature or adjusts the remaining balance
     * if the most recent deposit did not get fully staked
     * @dev autoMint feature is invoked if the last created pool is in
     * the commit state
     */
    function poke() external;

    /// @notice Returns the WstTBY contract
    function getWstTBY() external view returns (IWstTBY);

    /// @notice Returns the underlying token
    function getUnderlyingToken() external view returns (IERC20);

    /// @notice Returns the Bloom Pool Factory
    function getBloomFactory() external view returns (IBloomFactory);

    /// @notice Returns the Exchange Rate Registry
    function getExchangeRateRegistry() external view returns (IExchangeRateRegistry);

    /// @notice Returns the StakeUpStaking contract.
    function getStakeUpStaking() external view returns (IStakeUpStaking);

    /// @notice Returns the performanceBps.
    function getPerformanceBps() external view returns (uint256);

    /// @notice Returns if underlying tokens have been redeemed.
    function isTbyRedeemed(address tby) external view returns (bool);

    /// @notice The total shares of stTBY tokens in circulation on all chains
    function getGlobalShares() external view returns (uint256);
}
