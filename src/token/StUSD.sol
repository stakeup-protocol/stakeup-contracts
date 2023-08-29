// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./StUSDBase.sol";
import "../interfaces/IBloomPool.sol";

/// @title Staked USD Contract
contract StUSD is StUSDBase, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    /************************************/
    /************** Struct **************/
    /************************************/

    /// @notice Redemption state for account
    /// @param pending Pending redemption amount
    /// @param withdrawn Withdrawn redemption amount
    /// @param redemptionQueueTarget Target in vault's redemption queue
    struct Redemption {
        uint256 pending;
        uint256 withdrawn;
        uint256 redemptionQueueTarget;
    }

    /*************************************/
    /************** Storage **************/
    /*************************************/

    /// @dev Underlying token
    IERC20 public immutable underlyingToken;

    /// @dev Underlying token decimals
    uint8 internal immutable underlyingDecimals;

    /// @dev Mapping of TBY to bool
    mapping(address => bool) internal _whitelisted;

    /// @dev Total withdrawal balance
    uint256 internal _totalWithdrawalBalance;

    /// @dev Pending redemptions
    uint256 internal _pendingRedemptions;

    /// @dev Redemption queue
    uint256 internal _redemptionQueue;

    /// @dev Processed redemption queue
    uint256 internal _processedRedemptionQueue;

    /// @dev Mapping of account to redemption state
    mapping(address => Redemption) internal _redemptions;

    /// @dev Remaining underlying token balance
    uint256 internal _remainingBalance;

    /************************************/
    /************** Events **************/
    /************************************/

    /// @notice Emitted when new TBY is whitelisted
    /// @param tby TBY address
    /// @param whitelist whitelisted or not
    event TBYWhitelisted(address tby, bool whitelist);

    /// @notice Emitted when LP tokens are redeemed
    /// @param account Redeeming account
    /// @param shares Amount of LP tokens burned
    /// @param amount Amount of underlying tokens
    event Redeemed(address indexed account, uint256 shares, uint256 amount);

    /// @notice Emitted when redeemed underlying tokens are withdrawn
    /// @param account Withdrawing account
    /// @param amount Amount of underlying tokens withdrawn
    event Withdrawn(address indexed account, uint256 amount);

    /************************************/
    /************** Errors **************/
    /************************************/

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

    /// @notice TBY not whitelisted
    error TBYNotWhitelisted();

    constructor(address _underlyingToken) {
        if (_underlyingToken == address(0)) revert InvalidAddress();

        underlyingToken = IERC20(_underlyingToken);
        underlyingDecimals = IERC20Metadata(_underlyingToken).decimals();
    }

    /***********************************/
    /************ Functions ************/
    /***********************************/

    /// @notice Deposit TBY and get stUSD minted
    /// @param _tby TBY address
    /// @param _amount TBY amount to deposit
    function deposit(address _tby, uint256 _amount) external whenNotPaused {
        if (!_whitelisted[_tby]) revert TBYNotWhitelisted();

        IERC20(_tby).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 sharesAmount = getSharesByUsd(_amount);

        _mintShares(msg.sender, sharesAmount);

        _setTotalUsd(_getTotalUsd() + _amount);

        emit Deposit(msg.sender, _tby, _amount, sharesAmount);
    }

    /// @notice Redeem stUSD in exchange for underlying tokens. Underlying
    /// tokens can be withdrawn with the `withdraw()` method, once the
    /// redemption is processed.
    ///
    /// Emits a {Redeemed} event.
    ///
    /// @param _shares Amount of stUSD
    function redeem(uint256 _shares) external whenNotPaused nonReentrant {
        if (_shares == 0) revert ParameterOutOfBounds();

        uint256 redemptionAmount = getUsdByShares(_shares);

        _redeem(msg.sender, _shares, redemptionAmount, _redemptionQueue);

        _pendingRedemptions += redemptionAmount;
        _redemptionQueue += redemptionAmount;

        emit Redeemed(msg.sender, _shares, redemptionAmount);
    }

    /// @notice Withdraw redeemed underlying tokens
    ///
    /// Emits a {Withdrawn} event.
    ///
    function withdraw() external whenNotPaused nonReentrant {
        uint256 amount = redemptionAvailable(
            msg.sender,
            _processedRedemptionQueue
        );

        if (amount != 0) {
            _withdraw(msg.sender, amount);

            _totalWithdrawalBalance -= amount;

            underlyingToken.safeTransfer(
                msg.sender,
                amount / (10 ** (18 - underlyingDecimals))
            );
        }

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Get redemption state for account
    /// @param account Account
    /// @return Redemption state
    function redemptions(
        address account
    ) external view returns (Redemption memory) {
        return _redemptions[account];
    }

    /// @notice Get amount of redemption available for withdraw for account
    /// @param account Account
    /// @param processedRedemptionQueue Current value of processed redemption queue
    /// @return Amount available for withdraw
    function redemptionAvailable(
        address account,
        uint256 processedRedemptionQueue
    ) public view returns (uint256) {
        Redemption storage redemption = _redemptions[account];

        if (redemption.pending == 0) {
            return 0;
        } else if (
            processedRedemptionQueue >=
            redemption.redemptionQueueTarget + redemption.pending
        ) {
            return redemption.pending - redemption.withdrawn;
        } else if (
            processedRedemptionQueue > redemption.redemptionQueueTarget
        ) {
            return
                processedRedemptionQueue -
                redemption.redemptionQueueTarget -
                redemption.withdrawn;
        } else {
            return 0;
        }
    }

    function _redeem(
        address _account,
        uint256 _shares,
        uint256 _underlyingAmount,
        uint256 _redemptionQueueTarget
    ) internal {
        Redemption storage redemption = _redemptions[_account];

        if (balanceOf(_account) < _shares) revert InsufficientBalance();
        if (redemption.pending != 0) revert RedemptionInProgress();

        redemption.pending = _underlyingAmount;
        redemption.withdrawn = 0;
        redemption.redemptionQueueTarget = _redemptionQueueTarget;

        _burnShares(_account, _shares);
        _setTotalUsd(_getTotalUsd() - _underlyingAmount);
    }

    function _withdraw(address _account, uint256 _underlyingAmount) internal {
        Redemption storage redemption = _redemptions[_account];

        if (
            redemptionAvailable(_account, _processedRedemptionQueue) <
            _underlyingAmount
        ) revert InvalidAmount();

        if (redemption.withdrawn + _underlyingAmount == redemption.pending) {
            delete _redemptions[_account];
        } else {
            redemption.withdrawn += _underlyingAmount;
        }
    }

    /// @dev Process redemptions
    /// @param _proceeds Proceeds in underlying tokens
    function _processRedemptions(uint256 _proceeds) internal returns (uint256) {
        // Compute maximum redemption possible
        uint256 redemptionAmount = Math.min(_pendingRedemptions, _proceeds);

        // Update redemption state
        _pendingRedemptions -= redemptionAmount;
        _processedRedemptionQueue += redemptionAmount;

        // Add redemption to withdrawal balance
        _totalWithdrawalBalance += redemptionAmount;

        // Return amount of proceeds leftover
        return _proceeds - redemptionAmount;
    }

    /// @dev Process new proceeds by applying them to redemptions and undeployed
    /// cash
    /// @param _proceeds Proceeds in underlying tokens
    function _processProceeds(uint256 _proceeds) internal {
        // Process junior redemptions
        _proceeds = _processRedemptions(_proceeds);

        if (_proceeds > 0) {
            _remainingBalance += _proceeds;

            _setTotalUsd(_getTotalUsd() + _proceeds);
        }
    }

    /*************************************/
    /********** Owner Functions **********/
    /*************************************/

    /// @notice Update _totalUsd value
    /// @dev Restricted to owner only
    /// @param _amount new amount
    function setTotalUsd(uint256 _amount) external onlyOwner {
        _setTotalUsd(_amount);
    }

    /// @notice Whitelist TBY
    /// @dev Restricted to owner only
    /// @param _tby TBY address
    /// @param _whitelist whitelisted or not
    function whitelistTBY(address _tby, bool _whitelist) external onlyOwner {
        if (_tby == address(0)) revert InvalidAddress();
        _whitelisted[_tby] = _whitelist;
        emit TBYWhitelisted(_tby, _whitelist);
    }

    /// @notice Redeem underlying token from TBY
    /// @param _tby TBY address
    /// @param _amount Redeem amount
    function redeemUnderlying(
        address _tby,
        uint256 _amount
    ) external onlyOwner whenNotPaused {
        IBloomPool pool = IBloomPool(_tby);

        _amount = Math.min(_amount, IERC20(_tby).balanceOf(address(this)));

        uint256 beforeUnderlyingBalance = underlyingToken.balanceOf(
            address(this)
        );

        pool.withdrawLender(_amount);

        uint256 withdrawn = underlyingToken.balanceOf(address(this)) -
            beforeUnderlyingBalance;

        _processProceeds(withdrawn * 10 ** (18 - underlyingDecimals));
    }

    /// @notice Deposit remaining underlying token to new TBY
    /// @param _tby TBY address
    function depositUnderlying(address _tby) external onlyOwner whenNotPaused {
        IBloomPool pool = IBloomPool(_tby);

        uint256 amount = _remainingBalance;
        delete _remainingBalance;

        pool.depositLender(amount);
    }

    /// @notice Pause the contract
    /// @dev Restricted to owner only
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    /// @dev Restricted to owner only
    function unpause() external onlyOwner {
        _unpause();
    }
}
