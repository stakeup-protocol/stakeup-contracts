// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StUSDBase} from "./StUSDBase.sol";

import {IBloomFactory} from "../interfaces/IBloomFactory.sol";
import {IBloomPool} from "../interfaces/IBloomPool.sol";
import {IExchangeRateRegistry} from "../interfaces/IExchangeRateRegistry.sol";
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

    /**
     * @notice Fee type
     */
    enum FeeType {
        Mint,
        Redeem,
        Performance
    }

    // =================== Storage ===================

    /// @notice WstUSD token
    IWstUSD public wstUSD;

    /// @dev Underlying token
    IERC20 public underlyingToken;

    IBloomFactory public bloomFactory;

    IExchangeRateRegistry public registry;

    /// @dev Underlying token decimals
    uint8 internal _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 public immutable mintBps;

    /// @notice Redeem fee bps
    uint16 public immutable redeemBps;

    /// @notice Performance fee bps
    uint16 public immutable performanceBps;

    uint16 public constant BPS = 10000;

    uint16 public constant MAX_BPS = 200; // Max 2%

    uint256 public constant AUTO_STAKE_PHASE = 1 days;

    /// @notice Treasury address
    address public immutable treasury;

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

    /// @dev Last deposit amount
    uint256 internal _lastDepositAmount;

    /// @dev Remaining underlying token balance
    uint256 internal _remainingBalance;

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
     * @notice Emitted when a fee is captured and sent to the treasury
     * @param feeType Fee type
     * @param shares Number of stUSD shares sent to the treasury
     */
    event FeeCaptured(FeeType feeType, uint256 shares);

    // =================== Functions ===================
    constructor(
        address _underlyingToken,
        address _treasury,
        address _bloomFactory,
        address _registry,
        uint16 _mintBps, // Suggested default 0.5%
        uint16 _redeemBps, // Suggeste default 0.5%
        uint16 _performanceBps, // Suggested default 10% of yield
        address _layerZeroEndpoint,
        address _wstUSD
    )
        StUSDBase(_layerZeroEndpoint)
    {
        if (_underlyingToken == address(0)) revert InvalidAddress();
        if (_wstUSD == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_bloomFactory == address(0)) revert InvalidAddress();
        if (_registry == address(0)) revert InvalidAddress();
        if (_mintBps > MAX_BPS || _redeemBps > MAX_BPS) revert ParameterOutOfBounds();
        
        underlyingToken = IERC20(_underlyingToken);
        _underlyingDecimals = IERC20Metadata(_underlyingToken).decimals();
        treasury = _treasury;
        bloomFactory = IBloomFactory(_bloomFactory);
        registry = IExchangeRateRegistry(_registry);

        mintBps = _mintBps;
        redeemBps = _redeemBps;
        performanceBps = _performanceBps;

        wstUSD = IWstUSD(_wstUSD);
    }

    /**
     * @notice Get the total amount of underlying tokens in the pool
     */
    function getRemainingBalance() external view returns (uint256) {
        return _remainingBalance;
    }

    /**
     * @notice Deposit TBY and get stUSD minted
     * @param _tby TBY address
     * @param _amount TBY amount to deposit
     */
    function depositTby(address _tby, uint256 _amount) external {
        if (!registry.tokenInfos(_tby).active) revert TBYNotActive();
        IBloomPool latestPool = _getLatestPool();

        IERC20(_tby).safeTransferFrom(msg.sender, address(this), _amount);

        if (_tby == address(latestPool)) {
            _lastDepositAmount += _amount;
        }
        
        // TBYs will always have the same underlying decimals as the underlying token
        uint256 amountScaled = _amount * 10 ** (18 - _underlyingDecimals);

        uint256 sharesFeeAmount;
        uint256 mintFee = (amountScaled * mintBps) / BPS;

        if (mintFee > 0) {
            sharesFeeAmount = getSharesByUsd(mintFee);
            emit FeeCaptured(FeeType.Mint, sharesFeeAmount);
        }

        uint256 sharesAmount = getSharesByUsd(amountScaled - mintFee);

        _mintShares(msg.sender, sharesAmount);
        _mintShares(treasury, sharesFeeAmount);

        _setTotalUsd(_getTotalUsd() + amountScaled);

        emit Deposit(msg.sender, _tby, _amount, sharesAmount);
    }
    
    /**
     * @notice Deposit underlying tokens and get stUSD minted
     * @param _amount Amount of underlying tokens to deposit
     */
    function depostUnderlying(uint256 _amount) external {
        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        IBloomPool latestPool = _getLatestPool();

        if (latestPool.state() == IBloomPool.State.Commit) {
            _lastDepositAmount += _amount;
            underlyingToken.safeApprove(address(latestPool), _amount);
            latestPool.depositLender(_amount);
        } else {
            _remainingBalance += _amount;
        }
        
        uint256 amountScaled = _amount * 10 ** (18 - _underlyingDecimals);

        uint256 sharesFeeAmount;        
        uint256 mintFee = (amountScaled * mintBps) / BPS;

        if (mintFee > 0) {
            sharesFeeAmount = getSharesByUsd(mintFee);
            emit FeeCaptured(FeeType.Mint, sharesFeeAmount);
        }

        uint256 sharesAmount = getSharesByUsd(amountScaled - mintFee);

        _mintShares(msg.sender, sharesAmount);
        _mintShares(treasury, sharesFeeAmount);

        _setTotalUsd(_getTotalUsd() + amountScaled);

        emit Deposit(msg.sender, address(underlyingToken), _amount, sharesAmount);
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

        if (redemption.pending != 0) revert RedemptionInProgress();
        if (balanceOf(_account) < _underlyingAmount) revert InsufficientBalance();

        uint256 redeemFee = (_shares * redeemBps) / BPS;

        if (redeemFee > 0) {
            _shares -= redeemFee;
            uint256 redeemFeeAmount = getUsdByShares(redeemFee);
            _underlyingAmount -= redeemFeeAmount;
            _transfer(_account, treasury, redeemFeeAmount);
            emit FeeCaptured(FeeType.Redeem, redeemFee);
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
     * @param _redeemableProceeds Proceeds in underlying tokens that can be
     * used for redemptions
     */
    function _processRedemptions(uint256 _redeemableProceeds) internal returns (uint256) {
        // Compute maximum redemption possible
        uint256 redemptionAmount = Math.min(_pendingRedemptions, _redeemableProceeds);

        // Update redemption state
        _pendingRedemptions -= redemptionAmount;
        _processedRedemptionQueue += redemptionAmount;

        // Add redemption to withdrawal balance
        _totalWithdrawalBalance += redemptionAmount;

        // Return amount of proceeds leftover
        return _redeemableProceeds - redemptionAmount;
    }

    /**
     * @dev Process new proceeds by applying them to redemptions and undeployed
     * cash
     * @param _proceeds Proceeds in underlying tokens
     * @param _yield Yield gained from TBY
     */
    function _processProceeds(uint256 _proceeds, uint256 _yield) internal {
        uint256 scalingFactor = 10 ** (18 - _underlyingDecimals);
        uint256 underlyingGains = _yield * scalingFactor;

        uint256 performanceFee = underlyingGains * performanceBps / BPS;

        if (performanceFee > 0) {
            uint256 sharesFeeAmount = getSharesByUsd(performanceFee);

            _mintShares(treasury, sharesFeeAmount);
            emit FeeCaptured(FeeType.Performance, sharesFeeAmount);
        }
        
        // Process junior redemptions
        _proceeds = _processRedemptions(_proceeds);

        if (_proceeds > 0) {
            _remainingBalance += _proceeds / scalingFactor;
        }
        
        _setTotalUsd(_getTotalUsd() + underlyingGains);
    }

    /**
     * @notice Redeem underlying token from TBY
     * @param _tby TBY address
     * @param _amount Redeem amount
     */
    function redeemUnderlying(address _tby, uint256 _amount) external {
        IBloomPool pool = IBloomPool(_tby);

        _amount = Math.min(_amount, IERC20(_tby).balanceOf(address(this)));

        uint256 beforeUnderlyingBalance = underlyingToken.balanceOf(address(this));

        pool.withdrawLender(_amount);

        uint256 withdrawn = underlyingToken.balanceOf(address(this)) - beforeUnderlyingBalance;
        
        uint256 yieldFromPool = withdrawn - _amount;

        _processProceeds(withdrawn * 10 ** (18 - _underlyingDecimals), yieldFromPool);
    }

    /**
     * @notice Invokes the auto stake feature or adjusts the remaining balance
     * if the most recent deposit did not get fully staked
     * @dev autoMint feature is invoked if the last created pool is in
     * the commit state
     * @dev remainingBalance adjustment is invoked if the last created pool is
     * in any other state than commit and deposits dont get fully staked
     * @dev anyone can call this function for now
     */
    function poke() external {
        IBloomPool lastCreatedPool = _getLatestPool();

        IBloomPool.State currentState = lastCreatedPool.state();

        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            _autoMintTBY(lastCreatedPool);
        }

        if (_isElegibleForAdjustment(currentState)) {
            _adjustRemainingBalance(lastCreatedPool);
        }
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     */
    function _autoMintTBY(IBloomPool pool) internal {
        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));
        
        if (underlyingBalance > 0) {
            uint256 accountedBalance = _remainingBalance;
            uint256 unregisteredBalance = underlyingBalance - accountedBalance;
            
            delete _remainingBalance;

            underlyingToken.safeApprove(address(pool), underlyingBalance);
            pool.depositLender(underlyingBalance);

            _lastDepositAmount += underlyingBalance;

            uint256 scaledUnregisteredBalance = unregisteredBalance * 10 ** (18 - _underlyingDecimals);

            _setTotalUsd(_getTotalUsd() + scaledUnregisteredBalance);

            emit TBYAutoMinted(address(pool), underlyingBalance);
        }
    }

    function _within24HoursOfCommitPhaseEnd(IBloomPool pool, IBloomPool.State currentState) internal view returns (bool) {
        uint256 commitPhaseEnd = pool.COMMIT_PHASE_END();
        uint256 last24hoursOfCommitPhase = pool.COMMIT_PHASE_END() - AUTO_STAKE_PHASE;

        if (currentState == IBloomPool.State.Commit) {
            uint256 currentTime = block.timestamp;
            if (currentTime >= last24hoursOfCommitPhase && currentTime < commitPhaseEnd) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Check if the pool is elegible for adjustment
     * @param _state Pool state
     * @return bool True if the pool is in a state that allows for adjustment
     */
    function _isElegibleForAdjustment(IBloomPool.State _state) internal pure returns (bool) {
        return _state != IBloomPool.State.Commit
            && _state != IBloomPool.State.FinalWithdraw
            && _state != IBloomPool.State.EmergencyExit;
    }

    /**
     * @notice Adjust the remaining balance to account for the difference between
     * the last deposit amount and the current balance of the latest TBYs
     * @param pool The latest Bloom pool
     */
    function _adjustRemainingBalance(IBloomPool pool) internal {
        uint256 latestTbyBalance = IERC20(address(pool)).balanceOf(address(this));

        if (_lastDepositAmount > latestTbyBalance) {
            uint256 depositDifference = _lastDepositAmount - latestTbyBalance;
            _remainingBalance += depositDifference;
            emit RemainingBalanceAdjusted(_remainingBalance);
        }
    }

    /**
     * @notice Gets the latest pool created by the BloomFactory
     * @return IBloomPool The latest pool
     */
    function _getLatestPool() internal view returns (IBloomPool) {
        return IBloomPool(bloomFactory.getLastCreatedPool());
    }
}
