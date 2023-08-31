// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./StUSDBase.sol";
import "../interfaces/IBloomPool.sol";
import "../interfaces/IWstUSD.sol";

/// @title Staked USD Contract
contract StUSD is StUSDBase, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstUSD;

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

    /// @notice WstUSD token
    IWstUSD public wstUSD;

    /// @dev Underlying token
    IERC20 public immutable underlyingToken;

    /// @dev Underlying token decimals
    uint8 internal immutable _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 public mintBps;

    /// @notice Redeem fee bps
    uint16 public redeemBps;

    uint16 public constant BPS = 10000;

    uint16 public constant MAX_BPS = 200; // Max 2%

    /// @notice Treasury address
    address public treasury;

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

    /// @notice Emitted when mintBps is updated
    /// @param mintBps New mint bps value
    event MintBpsUpdated(uint16 mintBps);

    /// @notice Emitted when redeempBps is updated
    /// @param redeempBps New redeemp bps value
    event RedeemBpsUpdated(uint16 redeempBps);

    /// @notice Emitted when treasury is updated
    /// @param treasury New treasury address
    event TreasuryUpdated(address treasury);

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

    /// @notice WstUSD already initialized
    error AlreadyInitialized();

    /// @notice Constructor
    /// @param _underlyingToken The underlying token address
    /// @param _treasury Treasury address
    constructor(address _underlyingToken, address _treasury) {
        if (_underlyingToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();

        underlyingToken = IERC20(_underlyingToken);
        _underlyingDecimals = IERC20Metadata(_underlyingToken).decimals();
        treasury = _treasury;

        mintBps = 50; // Default 0.5%
        redeemBps = 50; // Default 0.5%
    }

    /// @notice Sets WstUSD token address
    /// @param _wstUSD WstUSD token address
    function setWstUSD(address _wstUSD) external onlyOwner {
        if (_wstUSD == address(0)) revert InvalidAddress();
        if (address(wstUSD) != address(0)) revert AlreadyInitialized();

        wstUSD = IWstUSD(_wstUSD);
    }

    /***********************************/
    /************ Functions ************/
    /***********************************/

    /// @notice Deposit TBY and get stUSD minted
    /// @param _tby TBY address
    /// @param _amount TBY amount to deposit
    function deposit(address _tby, uint256 _amount) external whenNotPaused {
        if (!_whitelisted[_tby]) revert TBYNotWhitelisted();

        uint256 mintFee = (_amount * mintBps) / BPS;

        if (mintFee > 0) {
            _amount -= mintFee;
            IERC20(_tby).safeTransferFrom(msg.sender, treasury, mintFee);
        }
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
    /// @param _stUSDAmount Amount of stUSD
    function redeemStUSD(
        uint256 _stUSDAmount
    ) external whenNotPaused nonReentrant {
        _redeemStUSD(_stUSDAmount);
    }

    /// @notice Redeem wstUSD in exchange for underlying tokens. Underlying
    /// tokens can be withdrawn with the `withdraw()` method, once the
    /// redemption is processed.
    ///
    /// Emits a {Redeemed} event.
    ///
    /// @param _wstUSDAmount Amount of wstUSD
    function redeemWstUSD(
        uint256 _wstUSDAmount
    ) external whenNotPaused nonReentrant {
        wstUSD.safeTransferFrom(msg.sender, address(this), _wstUSDAmount);
        uint256 _stUSDAmount = wstUSD.unwrap(_wstUSDAmount);
        _transfer(address(this), msg.sender, _stUSDAmount);
        _redeemStUSD(_stUSDAmount);
    }

    function _redeemStUSD(uint256 _stUSDAmount) internal {
        if (_stUSDAmount == 0) revert ParameterOutOfBounds();

        uint256 shares = getSharesByUsd(_stUSDAmount);

        _redeem(msg.sender, shares, _stUSDAmount, _redemptionQueue);

        _pendingRedemptions += _stUSDAmount;
        _redemptionQueue += _stUSDAmount;

        emit Redeemed(msg.sender, shares, _stUSDAmount);
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

            uint256 transferAmount = amount /
                (10 ** (18 - _underlyingDecimals));
            uint256 redeemFee = (transferAmount * redeemBps) / BPS;
            if (redeemFee > 0) {
                transferAmount -= redeemFee;
                underlyingToken.safeTransfer(treasury, redeemFee);
            }
            underlyingToken.safeTransfer(msg.sender, transferAmount);
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

    /// @notice Set mintBps value
    /// @dev Restricted to owner only
    /// @param _mintBps new mintBps value
    function setMintBps(uint16 _mintBps) external onlyOwner {
        if (_mintBps > MAX_BPS) revert ParameterOutOfBounds();
        mintBps = _mintBps;

        emit MintBpsUpdated(_mintBps);
    }

    /// @notice Set redeemBps value
    /// @dev Restricted to owner only
    /// @param _redeemBps new redeemBps value
    function setRedeemBps(uint16 _redeemBps) external onlyOwner {
        if (_redeemBps > MAX_BPS) revert ParameterOutOfBounds();
        redeemBps = _redeemBps;

        emit RedeemBpsUpdated(_redeemBps);
    }

    /// @notice Set treasury address
    /// @dev Restricted to owner only
    /// @param _treasury new treasury address
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;

        emit TreasuryUpdated(_treasury);
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

        _processProceeds(withdrawn * 10 ** (18 - _underlyingDecimals));
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
