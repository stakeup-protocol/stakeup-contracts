// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StUsdcLite} from "./StUsdcLite.sol";
import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";
import {StakeUpRewardMathLib} from "../rewards/lib/StakeUpRewardMathLib.sol";
import {StakeUpMintRewardLib} from "../rewards/lib/StakeUpMintRewardLib.sol";

import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IWstUsdc} from "../interfaces/IWstUsdc.sol";
import "forge-std/console2.sol";

/// @title Staked TBY Contract
contract StUsdc is IStUsdc, StUsdcLite, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstUsdc;

    // =================== Storage ===================

    /// @dev Underlying token
    IERC20 private immutable _asset;

    /// @dev TBY Contract
    ERC1155 private immutable _tby;

    /// @dev BloomPool Contract
    IBloomPool private immutable _bloomPool;

    /// @notice WstUsdc token
    IWstUsdc private immutable _wstUsdc;

    /// @dev StakeUp Staking Contract
    IStakeUpStaking private immutable _stakeupStaking;

    /// @dev SUP Token Contract
    IStakeUpToken private immutable _stakeupToken;

    /// @dev The total amount of stUsdc shares in circulation on all chains
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
    uint8 internal immutable _assetDecimals;

    /// @dev Mapping of TBYs that have been redeemed
    mapping(address => bool) private _tbyRedeemed;

    // ================== Constructor ==================

    constructor(
        address asset_,
        address bloomPool_,
        address stakeupStaking_,
        address wstUsdc_,
        address layerZeroEndpoint,
        address bridgeOperator
    ) StUsdcLite(layerZeroEndpoint, bridgeOperator) {
        if (asset_ == address(0) || stakeupStaking_ == address(0) || wstUsdc_ == address(0)) {
            revert Errors.InvalidAddress();
        }

        _asset = IERC20(asset_);
        _assetDecimals = IERC20Metadata(asset_).decimals();

        require(IBloomPool(bloomPool_).asset() == asset_, "Invalid underlying token");
        _bloomPool = IBloomPool(bloomPool_);
        _tby = ERC1155(bloomPool_.tby());

        _stakeupStaking = IStakeUpStaking(stakeupStaking_);
        _stakeupToken = IStakeUpStaking(stakeupStaking_).getStakupToken();
        _wstUsdc = IWstUsdc(wstUsdc_);

        _scalingFactor = 10 ** (18 - _assetDecimals);
        _startTimestamp = block.timestamp;
        _lastRateUpdate = block.timestamp;

        _pokeRewardsRemaining = Constants.POKE_REWARDS;
        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();
    }

    // =================== Functions ==================

    /// @inheritdoc IStUsdc
    function depositTby(uint256 tbyId, uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        require(!_bloomPool.isTbyRedeemable(tbyId), "TBY is redeemable");

        // If the token is a TBY, we need to get the current exchange rate of the token
        //     to accurately calculate the amount of stUsdc to mint.
        amountMinted = _bloomPool.getRate(tbyId).mulWad(amount);
        _deposit(amountMinted);
        emit TbyDeposited(msg.sender, tbyId, amount, amountMinted);
        _tby.safeTransferFrom(msg.sender, address(this), tbyId, amount, "");
    }

    /// @inheritdoc IStUsdc
    function depositAsset(uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        amountMinted = amount * _scalingFactor;
        _deposit(amountMinted);
        emit AssetDeposited(msg.sender, amount);
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IStUsdc
    function redeemStUsdc(uint256 amount) external nonReentrant returns (uint256 underlyingAmount) {
        if (amount == 0) revert Errors.ZeroAmount();
        if (balanceOf(msg.sender) < amount) {
            revert Errors.InsufficientBalance();
        }

        uint256 shares = getSharesByUsd(amount);

        underlyingAmount = amount / _scalingFactor;
        if (underlyingAmount > _asset.balanceOf(address(this))) {
            revert Errors.InsufficientBalance();
        }

        _burnShares(msg.sender, shares);
        _setTotalUsd(_getTotalUsd() - amount);
        _globalShares -= shares;

        emit Redeemed(msg.sender, shares, underlyingAmount);
        _asset.safeTransfer(msg.sender, underlyingAmount);
    }

    /// @inheritdoc IStUsdc
    function harvestTby(address tby) external override nonReentrant {
        uint256 lastRateUpdate = _lastRateUpdate;
        if (lastRateUpdate < block.timestamp - 24 hours) {
            revert Errors.RateUpdateNeeded();
        }
        if (!_registry.tokenInfos(tby).active) revert Errors.TBYNotActive();

        IBloomPool pool = IBloomPool(tby);
        uint256 amount = pool.balanceOf(address(this));
        uint256 beforeUnderlyingBalance = _asset.balanceOf(address(this));

        if (pool.state() == IBloomPool.State.EmergencyExit) {
            IEmergencyHandler emergencyHandler = IEmergencyHandler(pool.EMERGENCY_HANDLER());
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

        uint256 withdrawn = _asset.balanceOf(address(this)) - beforeUnderlyingBalance;

        _processProceeds(amount, withdrawn);

        if (!_tbyRedeemed[tby]) {
            _tbyRedeemed[tby] = true;
            _distributePokeRewards();
        }
    }

    /// @inheritdoc IStUsdc
    function poke() external nonReentrant {
        IBloomPool lastCreatedPool = _getLatestPool();
        IBloomPool.State currentState = lastCreatedPool.state();

        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            _autoMintTBY(lastCreatedPool);
        }

        uint256 currentBlock = block.timestamp;
        uint256 lastUpdate = _lastRateUpdate;
        if (currentBlock - lastUpdate >= 24 hours) {
            _accrueYield(_calcYieldAccrued(currentBlock, lastUpdate).divWadUp(_globalShares));
            _distributePokeRewards();
            _lastRateUpdate = currentBlock;
        }
    }

    /// @inheritdoc IStUsdc
    function asset() external view returns (IERC20) {
        return _asset;
    }

    /// @inheritdoc IStUsdc
    function wstUsdc() external view returns (IWstUsdc) {
        return _wstUsdc;
    }

    /// @inheritdoc IStUsdc
    function bloomPool() external view returns (IBloomPool) {
        return _bloomPool;
    }

    /// @inheritdoc IStUsdc
    function stakeUpStaking() external view returns (IStakeUpStaking) {
        return _stakeupStaking;
    }

    /// @inheritdoc IStUsdc
    function performanceBps() external pure returns (uint256) {
        return Constants.PERFORMANCE_BPS;
    }

    /// @inheritdoc IStUsdc
    function globalShares() external view override returns (uint256) {
        return _globalShares;
    }

    /// @inheritdoc IStUsdc
    function isTbyRedeemed(uint256 tbyId) external view returns (bool) {
        return _tbyRedeemed[tbyId];
    }

    /**
     * @notice Accounting logic for handling underlying asset and tby deposits.
     * @param amount The amount stUsdc being minted.
     */
    function _deposit(uint256 amount) internal {
        uint256 sharesAmount = getSharesByUsd(amount);
        if (sharesAmount == 0) revert Errors.ZeroAmount();

        _mintShares(msg.sender, sharesAmount);
        _globalShares += sharesAmount;

        uint256 mintRewardsRemaining = _mintRewardsRemaining;

        if (mintRewardsRemaining > 0) {
            uint256 eligibleAmount = Math.min(amount, mintRewardsRemaining);
            _mintRewardsRemaining -= eligibleAmount;

            _stakeupToken.mintRewards(msg.sender, eligibleAmount);
        }

        _setTotalUsd(_getTotalUsd() + amount);
    }

    /**
     * @notice Process the proceeds of TBYs and pay fees to StakeUp
     *   Staking
     * @param startingAmount Amount of USD that was initially deposited
     * @param amountWithdrawn Amount of USD that was withdrawn
     */
    function _processProceeds(uint256 startingAmount, uint256 amountWithdrawn) internal {
        uint256 proceeds = amountWithdrawn - startingAmount;
        uint256 yieldScaled = proceeds * _scalingFactor;
        uint256 performanceFee = (yieldScaled * _scalingFactor * Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;

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
    function _autoMintTBY(IBloomPool pool) internal returns (uint256 depositAmount) {
        depositAmount = _asset.balanceOf(address(this));

        if (depositAmount > 0) {
            _asset.safeApprove(address(pool), depositAmount);
            pool.depositLender(depositAmount);

            emit TBYAutoMinted(address(pool), depositAmount);
        }
    }

    /**
     * @notice Checks if a pool is within the last 24 hours of the commit phase
     * @param pool The Bloom Pool that is being checked
     * @param currentState The current state of the pool
     */
    function _within24HoursOfCommitPhaseEnd(IBloomPool pool, IBloomPool.State currentState)
        internal
        view
        returns (bool)
    {
        uint256 commitPhaseEnd = pool.COMMIT_PHASE_END();
        uint256 last24hoursOfCommitPhase = pool.COMMIT_PHASE_END() - Constants.AUTO_STAKE_PHASE;

        if (currentState == IBloomPool.State.Commit) {
            uint256 currentTime = block.timestamp;
            return currentTime >= last24hoursOfCommitPhase && currentTime < commitPhaseEnd;
        }

        return false;
    }

    /// @notice Calulates and mints SUP rewards to users who have poked the contract
    function _distributePokeRewards() internal {
        if (_pokeRewardsRemaining > 0) {
            uint256 amount = StakeUpRewardMathLib._calculateDripAmount(
                Constants.POKE_REWARDS, _startTimestamp, _pokeRewardsRemaining, false
            );

            if (amount > 0) {
                amount = Math.min(amount, _pokeRewardsRemaining);
                _pokeRewardsRemaining -= amount;
                IStakeUpToken(_stakeupToken).mintRewards(msg.sender, amount);
            }
        }
    }

    /// @notice Calculates the yield accrued by the stUsdc contract since the last update
    function _calcYieldAccrued(uint256 blockTimestamp, uint256 lastRateUpdate)
        internal
        view
        returns (uint256 yieldAccrued)
    {
        address[] memory tbys = _registry.getActiveTokens();
        uint256 currentRate = _scaleBpsRate(_bpsFeed.getWeightedRate());
        uint256 timeElapsed = blockTimestamp - lastRateUpdate;

        uint256 length = tbys.length;
        for (uint256 i = 0; i < length; ++i) {
            IBloomPool tby = IBloomPool(tbys[i]);
            uint256 balance = tby.balanceOf(address(this));

            if (balance != 0) {
                IBloomPool.State state = tby.state();
                if (_isValidTbyState(state)) {
                    yieldAccrued += (currentRate * timeElapsed * balance) / Math.WAD;
                    continue;
                }
                if (state > IBloomPool.State.Holding) {
                    uint256 poolPhaseEnd = tby.POOL_PHASE_END();
                    uint256 poolTimeElapsed = poolPhaseEnd - lastRateUpdate;
                    if (poolTimeElapsed != 0) {
                        yieldAccrued += (currentRate * poolTimeElapsed * balance) / Math.WAD;
                    }
                }
            }
        }
    }
}
