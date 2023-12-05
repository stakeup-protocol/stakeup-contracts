// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IWstUSD} from "./IWstUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBloomFactory} from "./bloom/IBloomFactory.sol";
import {IExchangeRateRegistry} from "./bloom/IExchangeRateRegistry.sol";
import {IStakeupStaking} from "./IStakeupStaking.sol";
import {IRewardManager} from "./IRewardManager.sol";
import {RedemptionNFT} from "src/token/RedemptionNFT.sol";

interface IStUSD {
    // =================== Errors ===================

    /// @notice Caller is not the Redemption NFT
    error CallerNotUnStUSD();

    /// @notice Invalid address (e.g. zero address)
    error InvalidAddress();

    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Invalid amount
    error InvalidAmount();
    
    /// @notice Invalid Underlying Token
    error InvalidUnderlyingToken();
    
    /// @notice TBY not active
    error TBYNotActive();

    /// @notice WstUSD already initialized
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
     * @param shares Number of stUSD shares sent to the Stakeup Staking
     */
    event FeeCaptured(FeeType feeType, uint256 shares);

    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param sharesAmount Amount of shares transferred 
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesAmount);

    /**
     * @notice An executed `burnShares` request
     * @dev Reports simultaneously burnt shares amount
     * and corresponding stUSD amount.
     * The stUSD amount is calculated twice: before and after the burning incurred rebase.
     * @param account holder of the burnt shares
     * @param preRebaseTokenAmount amount of stUSD the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount amount of stUSD the burnt shares corresponded to after the burn
     * @param sharesAmount amount of burnt shares
    */
    event SharesBurnt(
        address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
    );

    /**
     * @notice Emitted when user deposits
     * @param account User address
     * @param token Address of the token being deposited
     * @param amount Amount of tokens deposited
     * @param shares Amount of shares minted to the user
     */
    event Deposit(address indexed account, address token, uint256 amount, uint256 shares);
    
    /**
     * @return the entire amount of Usd controlled by the protocol.
     * @dev The sum of all USD balances in the protocol, equals to the total supply of stUSD.
     */
    function getTotalUsd() external view returns (uint256);
    /**
     * @notice Get the total amount of shares in existence.
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function getTotalShares() external view returns (uint256);
        /**
     * @notice Get the amount of shares owned by `_account`
     * @param account Account to get shares of
     */
    function sharesOf(address account) external view returns (uint256);

    /**
     * @notice Get the amount of shares that corresponds to a given dollar value.
     * @param usdAmount Amount of Usd
     */
    function getSharesByUsd(uint256 usdAmount) external view returns (uint256);

    /**
     * @notice Get the amount of Usd that corresponds to a given number of token shares.
     * @param sharesAmount Amount of shares
     * @return Amount of Usd that corresponds to `sharesAmount` token shares.
     */
    function getUsdByShares(uint256 sharesAmount) external view returns (uint256);

    /**
     * @notice Deposit TBY and get stUSD minted
     * @param tby TBY address
     * @param amount TBY amount to deposit
     */
    function depositTby(address tby, uint256 amount) external;
    /**
     * @notice Deposit underlying tokens and get stUSD minted
     * @param amount Amount of underlying tokens to deposit
     */
    function depostUnderlying(uint256 amount) external;

    /**
     * @notice Redeem stUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param stUSDAmount Amount of stUSD
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemStUSD(uint256 stUSDAmount) external returns (uint256);
   
    /**
     * @notice Redeem wstUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param wstUSDAmount Amount of wstUSD
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemWstUSD(uint256 wstUSDAmount) external returns (uint256);
 
    /// @notice Get the total amount of underlying tokens in the pool
    function getRemainingBalance() external view returns (uint256);

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

    /// @notice Returns the WstUSD contract
    function getWstUSD() external view returns (IWstUSD);

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
}
