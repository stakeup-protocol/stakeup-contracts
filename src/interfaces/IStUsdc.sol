// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {IStakeUpStaking} from "./IStakeUpStaking.sol";
import {IStUsdcLite} from "./IStUsdcLite.sol";
import {IWstUsdc} from "./IWstUsdc.sol";

interface IStUsdc is IStUsdcLite {
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
     * @notice Redeems the underlying token from a Bloom Pool in exchange for TBYs
     * @dev Underlying tokens can only be redeemed if stUsdc contains a TBY which is
     *     in its FinalWithdrawal state.
     * @param tbyId The tokenID of a TBY
     */
    function harvestTby(uint256 tbyId) external;

    /**
     * @notice Invokes the auto stake feature or adjusts the remaining balance
     * if the most recent deposit did not get fully staked
     * @dev autoMint feature is invoked if the last created pool is in
     * the commit state
     */
    function poke() external;

    /// @notice Returns the WstUsdc contract
    function getWstUsdc() external view returns (IWstUsdc);

    /// @notice Returns the underlying token
    function asset() external view returns (IERC20);

    /// @notice Returns the Bloom Pool Factory
    function getBloomFactory() external view returns (IBloomFactory);

    /// @notice Returns the Exchange Rate Registry
    function getExchangeRateRegistry() external view returns (IExchangeRateRegistry);

    /// @notice Returns the StakeUpStaking contract.
    function getStakeUpStaking() external view returns (IStakeUpStaking);

    /// @notice Returns the performanceBps.
    function getPerformanceBps() external view returns (uint256);

    /// @notice Returns if underlying tokens from a TBY have been redeemed.
    function isTbyRedeemed(uint256 tbyId) external view returns (bool);

    /// @notice The total shares of stUsdc tokens in circulation on all chains
    function getGlobalShares() external view returns (uint256);
}
