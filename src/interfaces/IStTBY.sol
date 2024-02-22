// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IWstTBY} from "./IWstTBY.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBloomFactory} from "./bloom/IBloomFactory.sol";
import {IExchangeRateRegistry} from "./bloom/IExchangeRateRegistry.sol";
import {IStakeupStaking} from "./IStakeupStaking.sol";
import {IRewardManager} from "./IRewardManager.sol";
import {IStTBYBase} from "./IStTBYBase.sol";

import {RedemptionNFT} from "src/token/RedemptionNFT.sol";

interface IStTBY is IStTBYBase {
    // =================== Errors ===================

    /// @notice Caller is not the Redemption NFT
    error CallerNotUnStTBY();

    /// @notice Invalid address (e.g. zero address)
    error InvalidAddress();

    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Invalid amount
    error InvalidAmount();

    /// @notice Invalid Redemption of Underlying Tokens
    error InvalidRedemption();
    
    /// @notice Invalid Underlying Token
    error InvalidUnderlyingToken();
    
    /// @notice TBY not active
    error TBYNotActive();

    /// @notice WstTBY already initialized
    error AlreadyInitialized();

    /// @notice Zero amount
    error ZeroAmount();

    // =================== Struct ====================

    /**
     * @notice Fee type
     */
    enum FeeType {
        Mint,
        Redeem,
        Performance
    }

    // =================== Events ===================

    /**
     * @notice Emitted when LP tokens are redeemed
     * @param account Redeeming account
     * @param shares Amount of LP tokens burned
     * @param amount Amount of underlying tokens
     */
    event Redeemed(address indexed account, uint256 shares, uint256 amount);

    /**
     * @notice Emitted when redeemed underlying tokens are withdrawn
     * @param account Withdrawing account
     * @param amount Amount of underlying tokens withdrawn
     */
    event Withdrawn(address indexed account, uint256 amount);

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
     * @notice Emitted when a fee is captured and sent to the Stakeup Staking
     * @param feeType Fee type
     * @param shares Number of stTBY shares sent to the Stakeup Staking
     */
    event FeeCaptured(FeeType feeType, uint256 shares);

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
     */
    function depositTby(address tby, uint256 amount) external;
    /**
     * @notice Deposit underlying tokens and get stTBY minted
     * @param amount Amount of underlying tokens to deposit
     */
    function depositUnderlying(uint256 amount) external;

    /**
     * @notice Redeem stTBY in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param stTBYAmount Amount of stTBY
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemStTBY(uint256 stTBYAmount) external returns (uint256);
   
    /**
     * @notice Redeem wstTBY in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param wstTBYAmount Amount of wstTBY
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemWstTBY(uint256 wstTBYAmount) external returns (uint256);
 
    /**
     * @notice Redeems the underlying token from a Bloom Pool in exchange for TBYs
     * @dev Underlying tokens can only be redeemed if stTBY contains a TBY which is
     *     in its FinalWithdrawal state.
     * @param tby TBY address
     */
    function redeemUnderlying(address tby) external;

    /**
     * @notice Withdraw redeemed underlying tokens
     * @dev Emits a {Withdrawn} event.
     * @dev Entrypoint for the withdrawl process is the RedemptionNFT contract
     */
    function withdraw(address account, uint256 shares) external;

    /**
     * 
     * @param remoteChainId The chainId of the remote chain
     * @param path abi.encodePacked(remoteAddress, localAddress)
     */
    function setNftTrustedRemote(uint16 remoteChainId, bytes calldata path) external;

    /// @notice Get the total amount of underlying tokens in the pool
    function getRemainingBalance() external view returns (uint256);

    /// @notice Returns the WstTBY contract
    function getWstTBY() external view returns (IWstTBY);

    /// @notice Returns the underlying token
    function getUnderlyingToken() external view returns (IERC20);

    /// @notice Returns the Bloom Pool Factory
    function getBloomFactory() external view returns (IBloomFactory);

    /// @notice Returns the Exchange Rate Registry
    function getExchangeRateRegistry() external view returns (IExchangeRateRegistry);

    /// @notice Returns the StakeupStaking contract.
    function getStakeupStaking() external view returns (IStakeupStaking);

    /// @notice Returns the RewardManager contract.
    function getRewardManager() external view returns (IRewardManager);

    /// @notice Returns the RedemptionNFT contract.
    function getRedemptionNFT() external view returns (RedemptionNFT);

    /// @notice Returns the mintBps.
    function getMintBps() external view returns (uint256);

    /// @notice Returns the redeemBps.
    function getRedeemBps() external view returns (uint256);

    /// @notice Returns the performanceBps.
    function getPerformanceBps() external view returns (uint256);

    /// @notice Returns if underlying tokens have been redeemed.
    function isTbyRedeemed(address tby) external view returns (bool);
}
