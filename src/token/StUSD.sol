// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StUSDBase} from "./StUSDBase.sol";

import {IBloomPool} from "../interfaces/IBloomPool.sol";
import {IWstUSD} from "../interfaces/IWstUSD.sol";

/// @title Staked USD Contract
contract StUSD is StUSDBase, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstUSD;

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

    // =================== Storage ===================

    /// @notice WstUSD token
    IWstUSD public wstUSD;

    /// @dev Underlying token
    IERC20 public underlyingToken;

    /// @dev Underlying token decimals
    uint8 internal _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 public mintBps;

    /// @notice Redeem fee bps
    uint16 public redeemBps;

    /// @notice Performance fee bps
    uint16 public performanceBps;

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

    // =================== Events ===================

    /**
     * @notice Emitted when mintBps is updated
     * @param mintBps New mint bps value
     */
    event MintBpsUpdated(uint16 mintBps);

    /**
     * @notice Emitted when redeempBps is updated
     * @param redeempBps New redeemp bps value
     */
    event RedeemBpsUpdated(uint16 redeempBps);

    /**
     * @notice Emitted when treasury is updated
     * @param treasury New treasury address
     */
    event TreasuryUpdated(address treasury);

    /**
     * Emitted when new TBY is whitelisted
     * @param tby TBY address
     * @param whitelist whitelist or not
     */
    event TBYWhitelisted(address tby, bool whitelist);

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

    // =================== Functions ===================
    constructor(
        address _underlyingToken,
        address _treasury,
        uint16 _mintBps, // Suggested default 0.5%
        uint16 _redeemBps, // Suggested default 0.5%
        uint16 _performanceBps, // Suggested default 10% of yield
        address _layerZeroEndpoint
    )
        StUSDBase(_layerZeroEndpoint)
    {
        if (_underlyingToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        
        underlyingToken = IERC20(_underlyingToken);
        _underlyingDecimals = IERC20Metadata(_underlyingToken).decimals();
        treasury = _treasury;

        mintBps = _mintBps;
        redeemBps = _redeemBps;
    }

    /**
     * Sets WstUSD token address
     * @param _wstUSD WstUSD token address
     */
    function setWstUSD(address _wstUSD) external onlyOwner {
        if (_wstUSD == address(0)) revert InvalidAddress();
        if (address(wstUSD) != address(0)) revert AlreadyInitialized();

        wstUSD = IWstUSD(_wstUSD);
    }

    /**
     * @notice Deposit TBY and get stUSD minted
     * @param _tby TBY address
     * @param _amount TBY amount to deposit
     */
    function deposit(address _tby, uint256 _amount) external {
        if (!_whitelisted[_tby]) revert TBYNotWhitelisted();

        IERC20(_tby).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 mintFee = (_amount * mintBps) / BPS;

        if (mintFee > 0) {
            _amount -= mintFee;
            uint256 sharesFeeAmount = getSharesByUsd(mintFee);
            _mintShares(treasury, sharesFeeAmount);
        }

        uint256 sharesAmount = getSharesByUsd(_amount);

        _mintShares(msg.sender, sharesAmount);

        _setTotalUsd(_getTotalUsd() + _amount);

        emit Deposit(msg.sender, _tby, _amount, sharesAmount);
    }

    /**
     * @notice Redeem stUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param _stUSDAmount Amount of stUSD
     */
    function redeemStUSD(uint256 _stUSDAmount) external nonReentrant {
        _redeemStUSD(_stUSDAmount);
    }

    /**
     * @notice Redeem wstUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param _wstUSDAmount Amount of wstUSD
     */
    function redeemWstUSD(uint256 _wstUSDAmount) external nonReentrant {
        IERC20(address(wstUSD)).safeTransferFrom(msg.sender, address(this), _wstUSDAmount);
        uint256 _stUSDAmount = wstUSD.unwrap(_wstUSDAmount);
        _transfer(address(this), msg.sender, _stUSDAmount);
        _redeemStUSD(_stUSDAmount);
    }

    function _redeemStUSD(uint256 _stUSDAmount) internal {
        if (_stUSDAmount == 0) revert ParameterOutOfBounds();

        uint256 shares = getSharesByUsd(_stUSDAmount);

        uint256 amountRedeemed = _redeem(msg.sender, shares, _stUSDAmount, _redemptionQueue);

        _pendingRedemptions += amountRedeemed;
        _redemptionQueue += amountRedeemed;

        emit Redeemed(msg.sender, shares, amountRedeemed);
    }

    /**
     * @notice Withdraw redeemed underlying tokens
     * @dev Emits a {Withdrawn} event.
     */
    function withdraw() external nonReentrant {
        uint256 amount = redemptionAvailable(msg.sender, _processedRedemptionQueue);

        if (amount != 0) {
            _withdraw(msg.sender, amount);

            _totalWithdrawalBalance -= amount;

            uint256 transferAmount = amount / (10 ** (18 - _underlyingDecimals));

            underlyingToken.safeTransfer(msg.sender, transferAmount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Get redemption state for account
     * @param account Account
     * @return Redemption state
     */
    function redemptions(address account) external view returns (Redemption memory) {
        return _redemptions[account];
    }

    /**
     * @notice Get amount of redemption available for withdraw for account
     * @param account Account
     * @param processedRedemptionQueue Current value of processed redemption queue
     * @return Amount available for withdraw
     */
    function redemptionAvailable(address account, uint256 processedRedemptionQueue) public view returns (uint256) {
        Redemption storage redemption = _redemptions[account];

        if (redemption.pending == 0) {
            return 0;
        } else if (processedRedemptionQueue >= redemption.redemptionQueueTarget + redemption.pending) {
            return redemption.pending - redemption.withdrawn;
        } else if (processedRedemptionQueue > redemption.redemptionQueueTarget) {
            return processedRedemptionQueue - redemption.redemptionQueueTarget - redemption.withdrawn;
        } else {
            return 0;
        }
    }

    function _redeem(address _account, uint256 _shares, uint256 _underlyingAmount, uint256 _redemptionQueueTarget)
        internal returns (uint256 amountRedeemed)
    {
        Redemption storage redemption = _redemptions[_account];

        if (balanceOf(_account) < _shares) revert InsufficientBalance();
        if (redemption.pending != 0) revert RedemptionInProgress();

        uint256 redeemFee = (_shares * redeemBps) / BPS;
        if (redeemFee > 0) {
            _shares -= redeemFee;
            uint256 redeemFeeAmount = getUsdByShares(redeemFee);
            _underlyingAmount -= redeemFeeAmount;
            transferFrom(_account, treasury, redeemFeeAmount);
        }

        redemption.pending = _underlyingAmount;
        redemption.withdrawn = 0;
        redemption.redemptionQueueTarget = _redemptionQueueTarget;

        _burnShares(_account, _shares);
        _setTotalUsd(_getTotalUsd() - _underlyingAmount);

        return _underlyingAmount;
    }

    function _withdraw(address _account, uint256 _underlyingAmount) internal {
        Redemption storage redemption = _redemptions[_account];

        if (redemptionAvailable(_account, _processedRedemptionQueue) < _underlyingAmount) revert InvalidAmount();

        if (redemption.withdrawn + _underlyingAmount == redemption.pending) {
            delete _redemptions[_account];
        } else {
            redemption.withdrawn += _underlyingAmount;
        }
    }

    /**
     * @dev Process redemptions
     * @param _proceeds Proceeds in underlying tokens
     */
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

    /**
     * @dev Process new proceeds by applying them to redemptions and undeployed
     * cash
     * @param _proceeds Proceeds in underlying tokens
     */
    function _processProceeds(uint256 _proceeds) internal {
        // Process junior redemptions
        _proceeds = _processRedemptions(_proceeds);

        if (_proceeds > 0) {
            _remainingBalance += _proceeds;

            _setTotalUsd(_getTotalUsd() + _proceeds);
        }
    }

    // ================ Owner Functions ==============

    /**
     * @notice Update _totalUsd value
     * @dev Restricted to owner only
     * @param _amount new amount
     */
    function setTotalUsd(uint256 _amount) external onlyOwner {
        _setTotalUsd(_amount);
    }

    /**
     * @notice Set mintBps value
     * @dev Restricted to owner only
     * @param _mintBps new mintBps value
     */
    function setMintBps(uint16 _mintBps) external onlyOwner {
        if (_mintBps > MAX_BPS) revert ParameterOutOfBounds();
        mintBps = _mintBps;

        emit MintBpsUpdated(_mintBps);
    }

    /**
     * @notice Set redeemBps value
     * @dev Restricted to owner only
     * @param _redeemBps new redeemBps value
     */
    function setRedeemBps(uint16 _redeemBps) external onlyOwner {
        if (_redeemBps > MAX_BPS) revert ParameterOutOfBounds();
        redeemBps = _redeemBps;

        emit RedeemBpsUpdated(_redeemBps);
    }

    /**
     * @notice Set treasury address
     * @dev Restricted to owner only
     * @param _treasury new treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;

        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Whitelist TBY
     * @dev Restricted to owner only
     * @param _tby TBY address
     * @param _whitelist whitelist or not
     */
    function whitelistTBY(address _tby, bool _whitelist) external onlyOwner {
        if (_tby == address(0)) revert InvalidAddress();
        _whitelisted[_tby] = _whitelist;
        emit TBYWhitelisted(_tby, _whitelist);
    }

    /**
     * @notice Redeem underlying token from TBY
     * @dev Restricted to owner only
     * @param _tby TBY address
     * @param _amount Redeem amount
     */
    // TODO: INVESTIGATE POTENTIAL DONATION ATTACK
    function redeemUnderlying(address _tby, uint256 _amount) external onlyOwner {
        IBloomPool pool = IBloomPool(_tby);

        _amount = Math.min(_amount, IERC20(_tby).balanceOf(address(this)));

        uint256 beforeUnderlyingBalance = underlyingToken.balanceOf(address(this));

        pool.withdrawLender(_amount);

        uint256 withdrawn = underlyingToken.balanceOf(address(this)) - beforeUnderlyingBalance;

        _processProceeds(withdrawn * 10 ** (18 - _underlyingDecimals));
    }

    /**
     * @notice Deposit remaining underlying token to new TBY
     * @param _tby TBY address
     */
    function depositUnderlying(address _tby) external onlyOwner {
        IBloomPool pool = IBloomPool(_tby);

        uint256 amount = _remainingBalance;
        delete _remainingBalance;

        pool.depositLender(amount);
    }
}
