// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {CrossChainLST} from "./CrossChainLST.sol";
import {StakeUpRewardMathLib} from "../rewards/lib/StakeUpRewardMathLib.sol";
import {StakeUpMintRewardLib} from "../rewards/lib/StakeUpMintRewardLib.sol";

import {IBloomFactory} from "../interfaces/bloom/IBloomFactory.sol";
import {IBloomPool} from "../interfaces/bloom/IBloomPool.sol";
import {IEmergencyHandler} from "../interfaces/bloom/IEmergencyHandler.sol";
import {IExchangeRateRegistry} from "../interfaces/bloom/IExchangeRateRegistry.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
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

    IStakeupStaking private immutable _stakeupStaking;

    IStakeupToken private immutable _stakeupToken;

    /// @dev Underlying token decimals
    uint8 internal immutable _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 private immutable mintBps;

    /// @notice Redeem fee bps
    uint16 private immutable redeemBps;

    /// @notice Performance fee bps
    uint16 private immutable performanceBps;

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

    /// @dev Mapping of TBYs that have been redeemed
    mapping(address => bool) private _tbyRedeemed;

    uint16 private constant BPS = 10000;

    uint16 private constant MAX_BPS = 200; // Max 2%

    uint256 private constant AUTO_STAKE_PHASE = 1 days;

    // =================== Functions ===================
    constructor(
        address underlyingToken,
        address stakeupStaking,
        address bloomFactory,
        address registry,
        uint16 mintBps_, // Suggested default 0.5%
        uint16 redeemBps_, // Suggested default 0.5%
        uint16 performanceBps_, // Suggested default 10% of yield
        address wstTBY,
        address messanger,
        bool pokeEligible,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) CrossChainLST(messanger, layerZeroEndpoint, layerZeroDelegate) {
        if (underlyingToken == address(0)) revert InvalidAddress();
        if (wstTBY == address(0)) revert InvalidAddress();
        if (bloomFactory == address(0)) revert InvalidAddress();
        if (registry == address(0)) revert InvalidAddress();
        if (stakeupStaking == address(0)) revert InvalidAddress();
        if (mintBps_ > MAX_BPS || redeemBps_ > MAX_BPS) {
            revert ParameterOutOfBounds();
        }

        _underlyingToken = IERC20(underlyingToken);
        _underlyingDecimals = IERC20Metadata(underlyingToken).decimals();
        _bloomFactory = IBloomFactory(bloomFactory);
        _registry = IExchangeRateRegistry(registry);
        _stakeupStaking = IStakeupStaking(stakeupStaking);

        _stakeupToken = IStakeupStaking(stakeupStaking).getStakupToken();

        mintBps = mintBps_;
        redeemBps = redeemBps_;
        performanceBps = performanceBps_;

        _scalingFactor = 10 ** (18 - _underlyingDecimals);
        _lastRateUpdate = block.timestamp;
        _startTimestamp = block.timestamp;

        if (pokeEligible) {
            _pokeRewardsRemaining = StakeUpRewardMathLib.POKE_REWARDS;
        }

        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();

        _wstTBY = IWstTBY(wstTBY);
    }

    /// @inheritdoc IStTBY
    function depositTby(
        address tby,
        uint256 amount,
        LzSettings calldata settings
    )
        external
        payable
        nonReentrant
        returns (
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        if (!_registry.tokenInfos(tby).active) revert TBYNotActive();

        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert InvalidUnderlyingToken();
        }

        IBloomPool latestPool = _getLatestPool();

        IERC20(tby).safeTransferFrom(msg.sender, address(this), amount);

        if (tby == address(latestPool)) {
            _lastDepositAmount += amount;
        }

        return _deposit(tby, amount, true, settings);
    }

    /// @inheritdoc IStTBY
    function depositUnderlying(
        uint256 amount,
        LzSettings calldata settings
    )
        external
        payable
        nonReentrant
        returns (
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        _underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        IBloomPool latestPool = _getLatestPool();

        if (latestPool.UNDERLYING_TOKEN() != address(_underlyingToken)) {
            revert InvalidUnderlyingToken();
        }

        if (latestPool.state() == IBloomPool.State.Commit) {
            _lastDepositAmount += amount;
            _underlyingToken.safeApprove(address(latestPool), amount);
            latestPool.depositLender(amount);
        } else {
            _remainingBalance += amount;
        }

        return _deposit(address(_underlyingToken), amount, false, settings);
    }

    /// @inheritdoc IStTBY
    function redeemStTBY(
        uint256 stTBYAmount,
        LzSettings calldata settings
    )
        external
        payable
        returns (
            uint256 underlyingRedeemed,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        return _redeemStTBY(stTBYAmount, settings);
    }

    /// @inheritdoc IStTBY
    function redeemWstTBY(
        uint256 wstTBYAmount,
        LzSettings calldata settings
    )
        external
        payable
        nonReentrant
        returns (
            uint256 underlyingRedeemed,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        IERC20(address(_wstTBY)).safeTransferFrom(
            msg.sender,
            address(this),
            wstTBYAmount
        );
        uint256 stTBYAmount = _wstTBY.unwrap(wstTBYAmount);
        _transferShares(address(this), msg.sender, wstTBYAmount);
        (underlyingRedeemed, bridgingReceipt, msgReceipts) = _redeemStTBY(
            stTBYAmount,
            settings
        );
    }

    /// @inheritdoc IStTBY
    function getRemainingBalance() external view returns (uint256) {
        return _remainingBalance;
    }

    /// @inheritdoc IStTBY
    function redeemUnderlying(
        address tby,
        LzSettings calldata settings
    )
        external
        payable
        override
        nonReentrant
        returns (
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        if (!_registry.tokenInfos(tby).active) revert TBYNotActive();

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

        if (withdrawn == 0) revert InvalidRedemption();

        uint256 lastRate = _lastRate[tby] == 0 ? 1e18 : _lastRate[tby];
        uint256 realizedValue = (lastRate * _scalingFactor * amount) / 1e18;

        (bridgingReceipt, msgReceipts) = _processProceeds(
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

        // If we haven't updated the values of TBYs in 12 hours, update it now
        if (block.timestamp - _lastRateUpdate >= 12 hours) {
            _lastRateUpdate = block.timestamp;
            msgReceipts = _syncYield(
                unregisteredBalance,
                true, // Increasing yield
                settings.messageSettings.options,
                settings.messageSettings.fee.nativeFee
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
    function getStakeupStaking() external view returns (IStakeupStaking) {
        return _stakeupStaking;
    }

    /// @inheritdoc IStTBY
    function getMintBps() external view returns (uint256) {
        return mintBps;
    }

    /// @inheritdoc IStTBY
    function getRedeemBps() external view returns (uint256) {
        return redeemBps;
    }

    /// @inheritdoc IStTBY
    function getPerformanceBps() external view returns (uint256) {
        return performanceBps;
    }

    /// @inheritdoc IStTBY
    function isTbyRedeemed(address tby) external view returns (bool) {
        return _tbyRedeemed[tby];
    }

    /**
     * @notice Deposit tokens into stTBY
     * @param settings LZBridge settings
     * @param token Token being deposited
     * @param amount The amount of tokens being deposited
     * @param isTby True if the token being deposited is a TBY
     */
    function _deposit(
        address token,
        uint256 amount,
        bool isTby,
        LzSettings calldata settings
    )
        internal
        returns (
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        // TBYs will always have the same underlying decimals as the underlying token
        uint256 amountScaled = amount * _scalingFactor;

        uint256 sharesFeeAmount;
        uint256 mintFee = (amountScaled * mintBps) / BPS;

        if (mintFee > 0) {
            sharesFeeAmount = getSharesByUsd(mintFee);

            emit FeeCaptured(FeeType.Mint, sharesFeeAmount);
        }

        // If the token is a TBY, we need to get the current exchange rate of the token
        //     to accurately calculate the amount of stTBY to mint.
        // We calculate the mint fee prior to getting the exchange rate to avoid punishing
        //     users for depositing TBYs once they have accrued interest.
        if (isTby) {
            amountScaled = _registry.getExchangeRate(token).mulWad(
                amountScaled
            );
        }

        uint256 sharesAmount = getSharesByUsd(amountScaled - mintFee);
        if (sharesAmount == 0) revert ZeroAmount();

        _mintShares(msg.sender, sharesAmount);
        _mintShares(address(_stakeupStaking), sharesFeeAmount);
        msgReceipts = _syncShares(
            sharesAmount + sharesFeeAmount,
            true, // Increasing shares
            settings.messageSettings.options,
            settings.messageSettings.fee.nativeFee
        );

        uint256 mintRewardsRemaining = _mintRewardsRemaining;

        if (mintRewardsRemaining > 0) {
            uint256 eligibleAmount = Math.min(
                amountScaled,
                mintRewardsRemaining
            );
            _mintRewardsRemaining -= eligibleAmount;

            _stakeupToken.mintRewards(msg.sender, eligibleAmount);
        }

        _setTotalUsd(_getTotalUsd() + amountScaled);
        bridgingReceipt = _stakeupStaking.processFees{
            value: settings.bridgeSettings.fee.nativeFee
        }(msg.sender, settings.bridgeSettings);

        emit Deposit(msg.sender, token, amount, sharesAmount);
    }

    /**
     * @notice Redeems stTBY in exchange for underlying tokens
     * @param stTBYAmount Amount of stTBY to redeem
     * @param settings LzSettings
     * @return underlyingAmount Amount of underlying tokens withdrawn from stTBY
     * @return bridgingReceipt Receipts for bridging using LayerZero
     */
    function _redeemStTBY(
        uint256 stTBYAmount,
        LzSettings calldata settings
    )
        internal
        returns (
            uint256 underlyingAmount,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        if (stTBYAmount == 0) revert ParameterOutOfBounds();
        if (balanceOf(msg.sender) < stTBYAmount) revert InsufficientBalance();

        uint256 shares = getSharesByUsd(stTBYAmount);
        (underlyingAmount, bridgingReceipt, msgReceipts) = _redeem(
            msg.sender,
            shares,
            settings
        );
    }

    function _redeem(
        address account,
        uint256 shares,
        LzSettings calldata settings
    )
        internal
        returns (
            uint256 underlyingAmount,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        uint256 redeemFee = (shares * redeemBps) / BPS;

        if (redeemFee > 0) {
            shares -= redeemFee;
            _transferShares(account, address(_stakeupStaking), redeemFee);

            emit FeeCaptured(FeeType.Redeem, redeemFee);
        }

        (underlyingAmount, bridgingReceipt, msgReceipts) = _withdraw(
            account,
            shares,
            settings
        );

        emit Redeemed(msg.sender, shares, underlyingAmount);
    }

    function _withdraw(
        address account,
        uint256 shares,
        LzSettings calldata settings
    )
        internal
        returns (
            uint256 underlyingAmount,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        uint256 amount = getUsdByShares(shares);
        uint256 underlyingBalance = _underlyingToken.balanceOf(address(this));

        if (amount != 0) {
            underlyingAmount = amount / _scalingFactor;

            if (underlyingAmount > underlyingBalance) {
                revert InsufficientBalance();
            }
            _underlyingToken.safeTransfer(account, underlyingAmount);

            _burnShares(account, shares);
            _setTotalUsd(_getTotalUsd() - amount);

            msgReceipts = _syncShares(
                shares,
                false, // Decreasing shares
                settings.messageSettings.options,
                settings.messageSettings.fee.nativeFee
            );
            bridgingReceipt = _stakeupStaking.processFees{
                value: settings.bridgeSettings.fee.nativeFee
            }(msg.sender, settings.bridgeSettings);
        }
    }

    /**
     * @notice Process the proceeds of TBYs and pay fees to Stakeup
     *   Staking
     * @param startingAmount Amount of USD that was initially deposited
     * @param amountWithdrawn Amount of USD that was withdrawn
     * @param realizedValue Value of proceeds that have already been
     *        accounted for in the protocol's total USD value
     * @param settings LZBridge settings
     */
    function _processProceeds(
        uint256 startingAmount,
        uint256 amountWithdrawn,
        uint256 realizedValue,
        LzSettings calldata settings
    )
        internal
        returns (
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        uint256 sharesFeeAmount;
        uint256 proceeds = amountWithdrawn - startingAmount;
        uint256 yieldScaled = proceeds * _scalingFactor;
        uint256 performanceFee = (yieldScaled * performanceBps) / BPS;

        if (performanceFee > 0) {
            sharesFeeAmount = getSharesByUsd(performanceFee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);

            emit FeeCaptured(FeeType.Performance, sharesFeeAmount);
        }

        if (proceeds > 0) {
            _remainingBalance += proceeds;
        }

        // TODO: Batchcall to LayerZero
        uint256 withdrawnScaled = amountWithdrawn * _scalingFactor;

        // If we have previously overestimated the yield, we need to remove the excess
        if (realizedValue > withdrawnScaled) {
            uint256 valueCorrection = realizedValue - withdrawnScaled;
            msgReceipts = _fullSync(
                sharesFeeAmount,
                valueCorrection,
                false,
                settings.messageSettings.options,
                settings.messageSettings.fee.nativeFee
            );
        }

        // If we have underestimated the yield, we need to distribute the difference
        if (withdrawnScaled > realizedValue) {
            uint256 unrealizedGains = withdrawnScaled - realizedValue;
            msgReceipts = _fullSync(
                sharesFeeAmount,
                unrealizedGains,
                true,
                settings.messageSettings.options,
                settings.messageSettings.fee.nativeFee
            );
        }

        bridgingReceipt = _stakeupStaking.processFees{
            value: settings.bridgeSettings.fee.nativeFee
        }(msg.sender, settings.bridgeSettings);
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     * @param pool The latest Bloom pool
     * @return unregisteredBalanceScaled The amount of liquidity added to the system
     *         that was not previously accounted for scaled to 1e18
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
            AUTO_STAKE_PHASE;

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
                    lastRate = 1e18;
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
                StakeUpRewardMathLib.POKE_REWARDS,
                _startTimestamp,
                _pokeRewardsRemaining,
                false
            );

            if (amount > 0) {
                amount = Math.min(amount, _pokeRewardsRemaining);
                _pokeRewardsRemaining -= amount;
                IStakeupToken(_stakeupToken).mintRewards(msg.sender, amount);
            }
        }
    }
}
