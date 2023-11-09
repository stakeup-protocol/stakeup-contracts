// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IStUSD {
    // =================== Errors ===================

    /// @notice Invalid address (e.g. zero address)
    error InvalidAddress();

    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Redemption in progress
    error RedemptionInProgress();

    /// @notice Invalid amount
    error InvalidAmount();

    /// @notice TBY not active
    error TBYNotActive();

    /// @notice WstUSD already initialized
    error AlreadyInitialized();

    /// @notice Zero amount
    error ZeroAmount();

    // =================== Struct ====================

    /**
     * @notice Redemption state for account
     * @param pending Pending redemption amount
     * @param withdrawn Withdrawn redemption amount
     * @param redemptionQueueTarget Target in vault's redemption queue
     */
    struct Redemption {
        uint256 pending;
        uint256 withdrawn;
        uint256 redemptionQueueTarget;
    }

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

    function getUsdByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByUsd(uint256 _usdAmount) external view returns (uint256);
}
