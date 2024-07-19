// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {CrossChainLST} from "./CrossChainLST.sol";
import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";
import {StakeUpRewardMathLib} from "../rewards/lib/StakeUpRewardMathLib.sol";
import {StakeUpMintRewardLib} from "../rewards/lib/StakeUpMintRewardLib.sol";

import {IBloomFactory} from "../interfaces/bloom/IBloomFactory.sol";
import {IBloomPool} from "../interfaces/bloom/IBloomPool.sol";
import {IEmergencyHandler} from "../interfaces/bloom/IEmergencyHandler.sol";
import {IExchangeRateRegistry} from "../interfaces/bloom/IExchangeRateRegistry.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStTBY} from "../interfaces/IStTBY.sol";
import {IWstTBY} from "../interfaces/IWstTBY.sol";

/// @title Staked TBY Contract
contract StTBY is IStTBY, CrossChainLST, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstTBY;

    // =================== Storage ===================

    /// @notice WstTBY token
    IWstTBY private immutable _wstTBY;

    /// @dev Underlying token
    IERC20 private immutable _underlyingToken;

    IBloomFactory private immutable _bloomFactory;

    IExchangeRateRegistry private immutable _registry;

    IStakeUpStaking private immutable _stakeupStaking;

    IStakeUpToken private immutable _stakeupToken;

    /// @dev Last deposit amount
    uint256 internal _lastDepositAmount;

    /// @dev Remaining underlying token balance
    uint256 internal _remainingBalance;

    /// @dev Mint rewards remaining
    uint256 internal _mintRewardsRemaining;

    /// @notice Amount of rewards remaining to be distributed to users for poking the contract
    uint256 private _pokeRewardsRemaining;

    /// @dev Last rate update timestamp
    uint256 internal _lastRateUpdate;

    /// @dev Deployment timestamp
    uint256 internal immutable _startTimestamp;

    /// @dev Scaling factor for underlying token
    uint256 private immutable _scalingFactor;

    /// @dev Underlying token decimals
    uint8 internal immutable _underlyingDecimals;

    /// @dev Mapping of TBYs that have been redeemed
    mapping(address => bool) private _tbyRedeemed;

    // ================== Constructor ==================

    constructor(
        address underlyingToken,
        address stakeupStaking,
        address bloomFactory,
        address registry,
        address wstTBY,
        address messenger,
        address layerZeroEndpoint,
        address bridgeOperator
    ) CrossChainLST(messenger, layerZeroEndpoint, bridgeOperator) {
        if (
            underlyingToken == address(0) ||
            bloomFactory == address(0) ||
            registry == address(0) ||
            stakeupStaking == address(0) ||
            wstTBY == address(0)
        ) {
            revert Errors.InvalidAddress();
        }

        _underlyingToken = IERC20(underlyingToken);
        _underlyingDecimals = IERC20Metadata(underlyingToken).decimals();
        _bloomFactory = IBloomFactory(bloomFactory);
        _registry = IExchangeRateRegistry(registry);
        _stakeupStaking = IStakeUpStaking(stakeupStaking);

        _stakeupToken = IStakeUpStaking(stakeupStaking).getStakupToken();

        _scalingFactor = 10 ** (18 - _underlyingDecimals);
        _lastRateUpdate = block.timestamp;
        _startTimestamp = block.timestamp;

        _pokeRewardsRemaining = Constants.POKE_REWARDS;

        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();

        _wstTBY = IWstTBY(wstTBY);
    }

    // =================== Functions ==================

    /// @inheritdoc IStTBY
    function depositTby(
        address tby,
        uint256 amount
    ) external payable nonReentrant returns (uint256 amountMinted) {
        if (!_registry.tokenInfos(tby).active) revert Errors.TBYNotActive();

        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert Errors.InvalidUnderlyingToken();
        }

        IBloomPool latestPool = _getLatestPool();

        IERC20(tby).safeTransferFrom(msg.sender, address(this), amount);

        if (tby == address(latestPool)) {
            _lastDepositAmount += amount;
        }

        return _deposit(tby, amount, true);
    }

    /// @inheritdoc IStTBY
    function depositUnderlying(
        uint256 amount
    ) external payable nonReentrant returns (uint256 amountMinted) {
        _underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        IBloomPool latestPool = _getLatestPool();

        if (latestPool.UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert Errors.InvalidUnderlyingToken();
        }

        if (latestPool.state() == IBloomPool.State.Commit) {
            _lastDepositAmount += amount;
            _underlyingToken.safeApprove(address(latestPool), amount);
            latestPool.depositLender(amount);
        } else {
            _remainingBalance += amount;
        }

        return _deposit(address(_underlyingToken), amount, false);
    }

    /// @inheritdoc IStTBY
    function redeemStTBY(
        uint256 amount
    ) external nonReentrant returns (uint256 underlyingAmount) {
        if (amount == 0) revert Errors.ZeroAmount();
        if (balanceOf(msg.sender) < amount) {
            revert Errors.InsufficientBalance();
        }

        uint256 shares = getSharesByUsd(amount);

        underlyingAmount = amount / _scalingFactor;
        if (underlyingAmount > _underlyingToken.balanceOf(address(this))) {
            revert Errors.InsufficientBalance();
        }

        _burnShares(msg.sender, shares);
        _setTotalUsd(_getTotalUsd() - amount);

        _underlyingToken.safeTransfer(msg.sender, underlyingAmount);

        emit Redeemed(msg.sender, shares, underlyingAmount);
    }

    /// @inheritdoc IStTBY
    function getRemainingBalance() external view returns (uint256) {
        return _remainingBalance;
    }

    /// @inheritdoc IStTBY
    function harvestTBY(
        address tby,
        LzSettings calldata settings
    )
        external
        payable
        override
        nonReentrant
        returns (MessagingReceipt[] memory msgReceipts)
    {
        if (!_registry.tokenInfos(tby).active) revert Errors.TBYNotActive();

        IBloomPool pool = IBloomPool(tby);
        uint256 amount = IERC20(tby).balanceOf(address(this));
        uint256 beforeUnderlyingBalance = _underlyingToken.balanceOf(
            address(this)
        );

        if (pool.state() == IBloomPool.State.EmergencyExit) {
            IEmergencyHandler emergencyHandler = IEmergencyHandler(
                pool.EMERGENCY_HANDLER()
            );
            IERC20(pool).safeApprove(address(emergencyHandler), amount);
            emergencyHandler.redeem(pool);

            // Update amount in the case that users cannot redeem all of their TBYs
            uint256 updatedBalance = IERC20(tby).balanceOf(address(this));
            if (updatedBalance != 0) {
                amount -= updatedBalance;
            }
        } else {
            pool.withdrawLender(amount);
        }

        uint256 withdrawn = _underlyingToken.balanceOf(address(this)) -
            beforeUnderlyingBalance;

        if (withdrawn == 0) revert Errors.InvalidRedemption();

        uint256 lastRate = _lastRate[tby] == 0
            ? Constants.FIXED_POINT_ONE
            : _lastRate[tby];
        uint256 realizedValue = (lastRate * _scalingFactor * amount) /
            Constants.FIXED_POINT_ONE;

        msgReceipts = _processProceeds(
            amount,
            withdrawn,
            realizedValue,
            settings
        );

        if (!_tbyRedeemed[tby]) {
            _tbyRedeemed[tby] = true;
            _distributePokeRewards();
        }
    }

    /// @inheritdoc IStTBY
    function poke(
        LzSettings calldata settings
    )
        external
        payable
        nonReentrant
        returns (MessagingReceipt[] memory msgReceipts)
    {
        IBloomPool lastCreatedPool = _getLatestPool();
        IBloomPool.State currentState = lastCreatedPool.state();

        uint256 unregisteredBalance;
        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            unregisteredBalance = _autoMintTBY(lastCreatedPool);
        }

        if (_isEligibleForAdjustment(currentState)) {
            _adjustRemainingBalance(lastCreatedPool);
        }

        // If we haven't updated the values of TBYs in 24 hours, update it now
        if (block.timestamp - _lastRateUpdate >= 24 hours) {
            _lastRateUpdate = block.timestamp;
            uint256 yieldIncrease = _getTbyYield() + unregisteredBalance;
            // True = increasing yield value
            msgReceipts = _fullSync(yieldIncrease, true, settings);

            _distributePokeRewards();
        }
    }

    /// @inheritdoc IStTBY
    function getWstTBY() external view returns (IWstTBY) {
        return _wstTBY;
    }

    /// @inheritdoc IStTBY
    function getUnderlyingToken() external view returns (IERC20) {
        return _underlyingToken;
    }

    /// @inheritdoc IStTBY
    function getBloomFactory() external view returns (IBloomFactory) {
        return _bloomFactory;
    }

    /// @inheritdoc IStTBY
    function getExchangeRateRegistry()
        external
        view
        returns (IExchangeRateRegistry)
    {
        return _registry;
    }

    /// @inheritdoc IStTBY
    function getStakeUpStaking() external view returns (IStakeUpStaking) {
        return _stakeupStaking;
    }

    /// @inheritdoc IStTBY
    function getPerformanceBps() external pure returns (uint256) {
        return Constants.PERFORMANCE_BPS;
    }

    /// @inheritdoc IStTBY
    function isTbyRedeemed(address tby) external view returns (bool) {
        return _tbyRedeemed[tby];
    }

    /**
     * @notice Deposit tokens into stTBY
     * @param token Token being deposited
     * @param amount The amount of tokens being deposited
     * @param isTby True if the token being deposited is a TBY
     */
    function _deposit(
        address token,
        uint256 amount,
        bool isTby
    ) internal returns (uint256 amountMinted) {
        // TBYs will always have the same underlying decimals as the underlying token
        amountMinted = amount * _scalingFactor;

        // If the token is a TBY, we need to get the current exchange rate of the token
        //     to accurately calculate the amount of stTBY to mint.
        // We calculate the mint fee prior to getting the exchange rate to avoid punishing
        //     users for depositing TBYs once they have accrued interest.
        if (isTby) {
            amountMinted = _registry.getExchangeRate(token).mulWad(
                amountMinted
            );
        }

        uint256 sharesAmount = getSharesByUsd(amountMinted);
        if (sharesAmount == 0) revert Errors.ZeroAmount();

        _mintShares(msg.sender, sharesAmount);

        uint256 mintRewardsRemaining = _mintRewardsRemaining;

        if (mintRewardsRemaining > 0) {
            uint256 eligibleAmount = Math.min(
                amountMinted,
                mintRewardsRemaining
            );
            _mintRewardsRemaining -= eligibleAmount;

            _stakeupToken.mintRewards(msg.sender, eligibleAmount);
        }

        _setTotalUsd(_getTotalUsd() + amountMinted);

        emit Deposit(msg.sender, token, amount, sharesAmount);
    }

    /**
     * @notice Process the proceeds of TBYs and pay fees to StakeUp
     *   Staking
     * @param startingAmount Amount of USD that was initially deposited
     * @param amountWithdrawn Amount of USD that was withdrawn
     * @param realizedValue Value of proceeds that have already been
     *        accounted for in the protocol's total USD value
     * @param settings LzMessaging settings
     */
    function _processProceeds(
        uint256 startingAmount,
        uint256 amountWithdrawn,
        uint256 realizedValue,
        LzSettings calldata settings
    ) internal returns (MessagingReceipt[] memory msgReceipts) {
        uint256 sharesFeeAmount;
        uint256 proceeds = amountWithdrawn - startingAmount;
        uint256 yieldScaled = proceeds * _scalingFactor;
        uint256 performanceFee = (yieldScaled * Constants.PERFORMANCE_BPS) /
            Constants.BPS_DENOMINATOR;

        if (performanceFee > 0) {
            sharesFeeAmount = getSharesByUsd(performanceFee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);

            emit FeeCaptured(sharesFeeAmount);
        }

        if (proceeds > 0) {
            _remainingBalance += proceeds;
        }

        uint256 withdrawnScaled = amountWithdrawn * _scalingFactor;

        // If we have previously overestimated the yield, we need to remove the excess
        if (realizedValue > withdrawnScaled) {
            uint256 valueCorrection = realizedValue - withdrawnScaled;
            msgReceipts = _fullSync(
                valueCorrection,
                false, // false = decreasing yieldvalue
                settings
            );
        }

        // If we have underestimated the yield, we need to distribute the difference
        if (withdrawnScaled > realizedValue) {
            uint256 unrealizedGains = withdrawnScaled - realizedValue;
            msgReceipts = _fullSync(
                unrealizedGains,
                true, // true = increasing yieldvalue
                settings
            );
        }

        _stakeupStaking.processFees();
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     * @param pool The latest Bloom pool
     * @return unregisteredBalanceScaled The amount of liquidity added to the system
     *         that was not previously accounted for scaled to Constants.FIXED_POINT_ONE
     */
    function _autoMintTBY(
        IBloomPool pool
    ) internal returns (uint256 unregisteredBalanceScaled) {
        uint256 underlyingBalance = _underlyingToken.balanceOf(address(this));

        if (underlyingBalance > 0) {
            uint256 accountedBalance = _remainingBalance;
            uint256 unregisteredBalance = underlyingBalance - accountedBalance;

            delete _remainingBalance;

            _underlyingToken.safeApprove(address(pool), underlyingBalance);
            pool.depositLender(underlyingBalance);

            _lastDepositAmount += underlyingBalance;

            emit TBYAutoMinted(address(pool), underlyingBalance);

            return unregisteredBalance * _scalingFactor;
        }
    }

    /**
     * @notice Checks if a pool is within the last 24 hours of the commit phase
     * @param pool The Bloom Pool that is being checked
     * @param currentState The current state of the pool
     */
    function _within24HoursOfCommitPhaseEnd(
        IBloomPool pool,
        IBloomPool.State currentState
    ) internal view returns (bool) {
        uint256 commitPhaseEnd = pool.COMMIT_PHASE_END();
        uint256 last24hoursOfCommitPhase = pool.COMMIT_PHASE_END() -
            Constants.AUTO_STAKE_PHASE;

        if (currentState == IBloomPool.State.Commit) {
            uint256 currentTime = block.timestamp;
            if (
                currentTime >= last24hoursOfCommitPhase &&
                currentTime < commitPhaseEnd
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Check if the pool is eligible for adjustment
     * @param state Pool state
     * @return bool True if the pool is in a state that allows for adjustment
     */
    function _isEligibleForAdjustment(
        IBloomPool.State state
    ) internal pure returns (bool) {
        return
            state != IBloomPool.State.Commit &&
            state != IBloomPool.State.PendingPreHoldSwap &&
            state != IBloomPool.State.FinalWithdraw &&
            state != IBloomPool.State.EmergencyExit;
    }

    /**
     * @notice Adjust the remaining balance to account for the difference between
     * the last deposit amount and the current balance of the latest TBYs
     * @param pool The latest Bloom pool
     * @return uint256 The difference between deposit amount and current balance
     */
    function _adjustRemainingBalance(
        IBloomPool pool
    ) internal returns (uint256) {
        uint256 depositDifference;
        uint256 latestTbyBalance = IERC20(address(pool)).balanceOf(
            address(this)
        );

        if (_lastDepositAmount > latestTbyBalance) {
            depositDifference = _lastDepositAmount - latestTbyBalance;
            _remainingBalance += depositDifference;
            emit RemainingBalanceAdjusted(_remainingBalance);
        }
        _lastDepositAmount = 0;

        return depositDifference;
    }

    /**
     * @notice Gets the latest pool created by the _bloomFactory
     * @return IBloomPool The latest pool
     */
    function _getLatestPool() internal view returns (IBloomPool) {
        return IBloomPool(_bloomFactory.getLastCreatedPool());
    }

    /**
     * @notice Calculates the current value of all TBYs that are staked in stTBY
     */
    function _getTbyYield() internal override returns (uint256 usdYield) {
        address[] memory tokens = _registry.getActiveTokens();

        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));

            if (tokenBalance > 0) {
                uint256 rate = _registry.getExchangeRate(tokens[i]);
                uint256 lastRate = _lastRate[tokens[i]];

                if (lastRate == 0) {
                    lastRate = Constants.FIXED_POINT_ONE;
                }

                uint256 rateDiff = rate - lastRate;
                usdYield += (
                    tokenBalance.rawMul(_scalingFactor).mulWad(rateDiff)
                );

                _lastRate[tokens[i]] = rate;
            }
        }
    }

    /// @notice Calulates and mints SUP rewards to users who have poked the contract
    function _distributePokeRewards() internal {
        if (_pokeRewardsRemaining > 0) {
            uint256 amount = StakeUpRewardMathLib._calculateDripAmount(
                Constants.POKE_REWARDS,
                _startTimestamp,
                _pokeRewardsRemaining,
                false
            );

            if (amount > 0) {
                amount = Math.min(amount, _pokeRewardsRemaining);
                _pokeRewardsRemaining -= amount;
                IStakeUpToken(_stakeupToken).mintRewards(msg.sender, amount);
            }
        }
    }
}
