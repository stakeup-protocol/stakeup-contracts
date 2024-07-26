// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StTBYBase} from "./StTBYBase.sol";
import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";
import {StakeUpRewardMathLib} from "../rewards/lib/StakeUpRewardMathLib.sol";
import {StakeUpMintRewardLib} from "../rewards/lib/StakeUpMintRewardLib.sol";

import {IBloomFactory} from "../interfaces/bloom/IBloomFactory.sol";
import {IBloomPool} from "../interfaces/bloom/IBloomPool.sol";
import {IBPSFeed} from "../interfaces/bloom/IBPSFeed.sol";
import {IEmergencyHandler} from "../interfaces/bloom/IEmergencyHandler.sol";
import {IExchangeRateRegistry} from "../interfaces/bloom/IExchangeRateRegistry.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStTBY} from "../interfaces/IStTBY.sol";
import {IWstTBY} from "../interfaces/IWstTBY.sol";

/// TODO: Create a tby deposit that prevents front running
///       - Switch to a index variable that increments based on yield added to the system
/// @title Staked TBY Contract
contract StTBY is IStTBY, StTBYBase, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IBloomPool;
    using SafeERC20 for IWstTBY;

    // =================== Storage ===================

    /// @notice WstTBY token
    IWstTBY private immutable _wstTBY;

    /// @dev Underlying token
    IERC20 private immutable _underlyingToken;

    IBloomFactory private immutable _bloomFactory;

    IExchangeRateRegistry private immutable _registry;

    IBPSFeed private immutable _bpsFeed;

    IStakeUpStaking private immutable _stakeupStaking;

    IStakeUpToken private immutable _stakeupToken;

    /// @dev The total amount of stTBY shares in circulation on all chains
    uint256 internal _globalShares;

    /// @dev Mint rewards remaining
    uint256 internal _mintRewardsRemaining;

    /// @notice Amount of rewards remaining to be distributed to users for poking the contract
    uint256 private _pokeRewardsRemaining;

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
        address bpsFeed,
        address wstTBY,
        address layerZeroEndpoint,
        address bridgeOperator
    ) StTBYBase(layerZeroEndpoint, bridgeOperator) {
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
        _bpsFeed = IBPSFeed(bpsFeed);
        _stakeupStaking = IStakeUpStaking(stakeupStaking);
        _stakeupToken = IStakeUpStaking(stakeupStaking).getStakupToken();
        _wstTBY = IWstTBY(wstTBY);

        _scalingFactor = 10 ** (18 - _underlyingDecimals);
        _startTimestamp = block.timestamp;

        _pokeRewardsRemaining = Constants.POKE_REWARDS;
        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();
    }

    // =================== Functions ==================

    /// @inheritdoc IStTBY
    function depositTby(
        address tby,
        uint256 amount
    ) external nonReentrant returns (uint256 amountMinted) {
        if (
            IBloomPool(tby).state() != IBloomPool.State.Holding ||
            !_registry.tokenInfos(tby).active
        ) {
            revert Errors.TBYNotActive();
        }

        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert Errors.InvalidUnderlyingToken();
        }

        IERC20(tby).safeTransferFrom(msg.sender, address(this), amount);

        return _deposit(tby, amount, true);
    }

    /// @inheritdoc IStTBY
    function depositUnderlying(
        uint256 amount
    ) external nonReentrant returns (uint256 amountMinted) {
        _underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        IBloomPool latestPool = _getLatestPool();

        if (latestPool.UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert Errors.InvalidUnderlyingToken();
        }

        if (latestPool.state() == IBloomPool.State.Commit) {
            _underlyingToken.safeApprove(address(latestPool), amount);
            latestPool.depositLender(amount);
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
        _globalShares -= shares;

        _underlyingToken.safeTransfer(msg.sender, underlyingAmount);

        emit Redeemed(msg.sender, shares, underlyingAmount);
    }

    /// @inheritdoc IStTBY
    function harvestTBY(address tby) external override nonReentrant {
        uint256 lastRateUpdate = _lastRateUpdate;
        if (lastRateUpdate < block.timestamp - 24 hours) {
            revert Errors.RateUpdateNeeded();
        }
        if (!_registry.tokenInfos(tby).active) revert Errors.TBYNotActive();

        IBloomPool pool = IBloomPool(tby);
        uint256 amount = pool.balanceOf(address(this));
        uint256 beforeUnderlyingBalance = _underlyingToken.balanceOf(
            address(this)
        );

        if (pool.state() == IBloomPool.State.EmergencyExit) {
            IEmergencyHandler emergencyHandler = IEmergencyHandler(
                pool.EMERGENCY_HANDLER()
            );
            pool.safeApprove(address(emergencyHandler), amount);
            emergencyHandler.redeemLender(pool);

            // Update amount in the case that users cannot redeem all of their TBYs
            uint256 updatedBalance = pool.balanceOf(address(this));
            if (updatedBalance != 0) {
                amount -= updatedBalance;
            }
        } else {
            if (lastRateUpdate < pool.COMMIT_PHASE_END()) {
                revert Errors.RateUpdateNeeded();
            }
            pool.withdrawLender(amount);
        }

        uint256 withdrawn = _underlyingToken.balanceOf(address(this)) -
            beforeUnderlyingBalance;

        _processProceeds(amount, withdrawn);

        if (!_tbyRedeemed[tby]) {
            _tbyRedeemed[tby] = true;
            _distributePokeRewards();
        }
    }

    /// @inheritdoc IStTBY
    function poke() external nonReentrant {
        IBloomPool lastCreatedPool = _getLatestPool();
        IBloomPool.State currentState = lastCreatedPool.state();

        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            _autoMintTBY(lastCreatedPool);
        }

        uint256 currentBlock = block.timestamp;
        uint256 lastUpdate = _lastRateUpdate;
        if (currentBlock - lastUpdate >= 24 hours) {
            _accrueYield(
                _calcYieldAccrued(currentBlock, lastUpdate).divWadUp(
                    _globalShares
                )
            );
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
    function getGlobalShares() external view override returns (uint256) {
        return _globalShares;
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
        // We then adjust the amount minted based on the time since the last rate update
        //     in order to prevent front running of rate updates which would result in
        //     overvaluing TBY yield.
        if (isTby) {
            uint256 timeSinceUpdate = _lastRateUpdate - block.timestamp;
            uint256 rateAdjustment = _scaleBpsRate(_bpsFeed.currentRate()) *
                timeSinceUpdate;

            amountMinted =
                _registry.getExchangeRate(token).mulWad(amountMinted) -
                rateAdjustment;
        }

        uint256 sharesAmount = getSharesByUsd(amountMinted);
        if (sharesAmount == 0) revert Errors.ZeroAmount();

        _mintShares(msg.sender, sharesAmount);
        _globalShares += sharesAmount;

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
     */
    function _processProceeds(
        uint256 startingAmount,
        uint256 amountWithdrawn
    ) internal {
        uint256 proceeds = amountWithdrawn - startingAmount;
        uint256 yieldScaled = proceeds * _scalingFactor;
        uint256 performanceFee = (yieldScaled *
            _scalingFactor *
            Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;

        if (performanceFee > 0) {
            uint256 sharesFeeAmount = getSharesByUsd(performanceFee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);
            _globalShares += sharesFeeAmount;

            emit FeeCaptured(sharesFeeAmount);
        }

        _stakeupStaking.processFees();
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     * @param pool The latest Bloom pool
     * @return depositAmount The amount of USDC deposited
     */
    function _autoMintTBY(
        IBloomPool pool
    ) internal returns (uint256 depositAmount) {
        depositAmount = _underlyingToken.balanceOf(address(this));

        if (depositAmount > 0) {
            _underlyingToken.safeApprove(address(pool), depositAmount);
            pool.depositLender(depositAmount);

            emit TBYAutoMinted(address(pool), depositAmount);
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
            return
                currentTime >= last24hoursOfCommitPhase &&
                currentTime < commitPhaseEnd;
        }

        return false;
    }

    /**
     * @notice Gets the latest pool created by the _bloomFactory
     * @return IBloomPool The latest pool
     */
    function _getLatestPool() internal view returns (IBloomPool) {
        return IBloomPool(_bloomFactory.getLastCreatedPool());
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

    /// @notice Calculates the yield accrued by the stTBY contract since the last update
    function _calcYieldAccrued(
        uint256 blockTimestamp,
        uint256 lastRateUpdate
    ) internal view returns (uint256 yieldAccrued) {
        address[] memory tbys = _registry.getActiveTokens();
        uint256 currentRate = _scaleBpsRate(_bpsFeed.currentRate());
        uint256 timeElapsed = blockTimestamp - lastRateUpdate;

        uint256 length = tbys.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 balance = IBloomPool(tbys[i]).balanceOf(address(this));

            if (balance != 0) {
                if (IBloomPool(tbys[i]).state() == IBloomPool.State.Holding) {
                    yieldAccrued +=
                        (currentRate * timeElapsed * balance) /
                        Math.WAD;
                } else {
                    uint256 poolPhaseEnd = IBloomPool(tbys[i]).POOL_PHASE_END();
                    if (poolPhaseEnd - timeElapsed > lastRateUpdate) {
                        uint256 poolTimeElapsed = poolPhaseEnd - lastRateUpdate;
                        yieldAccrued +=
                            (currentRate * poolTimeElapsed * balance) /
                            Math.WAD;
                    }
                }
            }
        }
    }

    /**
     * @notice Scales the BPS rate to a fixed point number
     * @dev 1e4: the initial rate of the BPSFeed
     * @dev 1e14: the scaling factor to convert the rate to a fixed point number
     * @param rate The rate to scale
     * @return The scaled rate
     */
    function _scaleBpsRate(uint256 rate) internal pure returns (uint256) {
        return (rate - 1e4) * 1e14;
    }
}
