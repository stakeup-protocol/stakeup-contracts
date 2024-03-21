// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RedemptionNFT} from "src/token/RedemptionNFT.sol";
import {StTBYBase} from "src/token/StTBYBase.sol";

import {IBloomFactory} from "src/interfaces/bloom/IBloomFactory.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";
import {IEmergencyHandler} from "src/interfaces/bloom/IEmergencyHandler.sol";
import {IExchangeRateRegistry} from "src/interfaces/bloom/IExchangeRateRegistry.sol";
import {IRewardManager} from "src/interfaces/IRewardManager.sol";
import {IStakeupStaking} from "src/interfaces/IStakeupStaking.sol";
import {IStTBY} from "src/interfaces/IStTBY.sol";
import {IWstTBY} from "src/interfaces/IWstTBY.sol";

/// @title Staked TBY Contract
contract StTBY is IStTBY, StTBYBase, ReentrancyGuard {
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

    IRewardManager private immutable _rewardManager;

    RedemptionNFT private immutable _redemptionNFT;

    /// @dev Underlying token decimals
    uint8 internal immutable _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 private immutable mintBps;

    /// @notice Redeem fee bps
    uint16 private immutable redeemBps;

    /// @notice Performance fee bps
    uint16 private immutable performanceBps;

    uint16 private constant BPS = 10000;

    uint16 private constant MAX_BPS = 200; // Max 2%

    uint256 private constant AUTO_STAKE_PHASE = 1 days;

    uint256 private constant MINT_REWARD_CUTOFF = 200_000_000e18;

    /// @dev Last deposit amount
    uint256 internal _lastDepositAmount;

    /// @dev Remaining underlying token balance
    uint256 internal _remainingBalance;

    /// @dev Mint rewards remaining
    uint256 internal _mintRewardsRemaining;

    /// @dev Last rate update timestamp
    uint256 internal _lastRateUpdate;

    /// @dev Scaling factor for underlying token
    uint256 public immutable _scalingFactor;

    /// @dev Mapping of TBYs that have been redeemed
    mapping(address => bool) private _tbyRedeemed;

    // =================== Modifiers ===================
    modifier onlyUnStTBY() {
        if (_msgSender() != address(_redemptionNFT)) revert CallerNotUnStTBY();
        _;
    }

    // =================== Functions ===================
    constructor(
        address underlyingToken,
        address stakeupStaking,
        address bloomFactory,
        address registry,
        uint16 mintBps_, // Suggested default 0.5%
        uint16 redeemBps_, // Suggested default 0.5%
        uint16 performanceBps_, // Suggested default 10% of yield
        address layerZeroEndpoint,
        address wstTBY
    )
        StTBYBase(layerZeroEndpoint)
    {
        if (underlyingToken == address(0)) revert InvalidAddress();
        if (wstTBY == address(0)) revert InvalidAddress();
        if (bloomFactory == address(0)) revert InvalidAddress();
        if (registry == address(0)) revert InvalidAddress();
        if (stakeupStaking == address(0)) revert InvalidAddress();
        if (mintBps_ > MAX_BPS || redeemBps_ > MAX_BPS) revert ParameterOutOfBounds();
        
        _underlyingToken = IERC20(underlyingToken);
        _underlyingDecimals = IERC20Metadata(underlyingToken).decimals();
        _bloomFactory = IBloomFactory(bloomFactory);
        _registry = IExchangeRateRegistry(registry);
        _stakeupStaking = IStakeupStaking(stakeupStaking);
        _rewardManager = IRewardManager(_stakeupStaking.getRewardManager());

        mintBps = mintBps_;
        redeemBps = redeemBps_;
        performanceBps = performanceBps_;

        _scalingFactor = 10 ** (18 - _underlyingDecimals);
        _lastRateUpdate = block.timestamp;
        _mintRewardsRemaining = MINT_REWARD_CUTOFF;

        _wstTBY = IWstTBY(wstTBY);

        _redemptionNFT = new RedemptionNFT(
            "stTBY Redemption NFT",
            "unstTBY",
            address(this),
            layerZeroEndpoint
        );
    }


/**************************** Diff Block Start ****************************
diff --git a/certora/munged/StTBYMunged.sol b/certora/munged/StTBYMunged.sol
index 923c7d3..b73243d 100644
--- a/certora/munged/StTBYMunged.sol
+++ b/certora/munged/StTBYMunged.sol
@@ -136,7 +136,7 @@ contract StTBY is IStTBY, StTBYBase, ReentrancyGuard {
     function depositTby(address tby, uint256 amount) external nonReentrant {
         if (!_registry.tokenInfos(tby).active) revert TBYNotActive();
         
-        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_underlyingToken)) {
+        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_bloomFactory)) {
             revert InvalidUnderlyingToken();
         }
 
**************************** Diff Block End *****************************/

    /// @inheritdoc IStTBY
    function depositTby(address tby, uint256 amount) external nonReentrant {
        if (!_registry.tokenInfos(tby).active) revert TBYNotActive();
        
        if (IBloomPool(tby).UNDERLYING_TOKEN() != address(_bloomFactory)) {
            revert InvalidUnderlyingToken();
        }

        IBloomPool latestPool = _getLatestPool();

        IERC20(tby).safeTransferFrom(msg.sender, address(this), amount);

        if (tby == address(latestPool)) {
            _lastDepositAmount += amount;
        }
        
        _deposit(tby, amount, true);
    }
    
    /// @inheritdoc IStTBY
    function depositUnderlying(uint256 amount) external nonReentrant {
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
        
        _deposit(address(_underlyingToken), amount, false);
    }

    /// @inheritdoc IStTBY
    function redeemStTBY(uint256 stTBYAmount) external nonReentrant returns (uint256) {
        return _redeemStTBY(stTBYAmount);
    }

    /// @inheritdoc IStTBY
    function redeemWstTBY(uint256 wstTBYAmount) external nonReentrant returns (uint256) {
        IERC20(address(_wstTBY)).safeTransferFrom(msg.sender, address(this), wstTBYAmount);
        uint256 stTBYAmount = _wstTBY.unwrap(wstTBYAmount);
        _transfer(address(this), msg.sender, stTBYAmount);
        return _redeemStTBY(stTBYAmount);
    }

    /// @inheritdoc IStTBY
    function getRemainingBalance() external view returns (uint256) {
        return _remainingBalance;
    }

    /// @inheritdoc IStTBY
    function withdraw(address account, uint256 shares) external override nonReentrant onlyUnStTBY {
        uint256 amount = getUsdByShares(shares);

        uint256 underlyingBalance = _underlyingToken.balanceOf(address(this));

        if (amount != 0) {
            uint256 transferAmount = amount / _scalingFactor;

            if (transferAmount > underlyingBalance) revert InsufficientBalance();

            _underlyingToken.safeTransfer(account, transferAmount);
    
            _burnShares(address(_redemptionNFT), shares);
            _setTotalUsd(_getTotalUsd() - amount);

        }

        emit Withdrawn(msg.sender, amount);
    }

    /// @inheritdoc IStTBY
    function redeemUnderlying(address tby) external override nonReentrant {
        if (!_registry.tokenInfos(tby).active) revert TBYNotActive();
        
        IBloomPool pool = IBloomPool(tby);
        
        uint256 amount = IERC20(tby).balanceOf(address(this));

        uint256 beforeUnderlyingBalance = _underlyingToken.balanceOf(address(this));
        
        if (pool.state() == IBloomPool.State.EmergencyExit) {
            IEmergencyHandler emergencyHandler = IEmergencyHandler(pool.EMERGENCY_HANDLER());
            IERC20(pool).safeApprove(address(emergencyHandler), amount);
            emergencyHandler.redeem(pool);
            // Update amount in the case that users cannot redeem all of their TBYs
            amount = IERC20(tby).balanceOf(address(this));
        } else {
            pool.withdrawLender(amount);
        }
        
        uint256 withdrawn = _underlyingToken.balanceOf(address(this)) - beforeUnderlyingBalance;

        if (withdrawn == 0) revert InvalidRedemption();

        uint256 yieldFromPool = withdrawn - amount;
        
        _processProceeds(withdrawn, yieldFromPool);

        if (yieldFromPool > 0 && !_tbyRedeemed[tby]) {
            _tbyRedeemed[tby] = true;
            _rewardManager.distributePokeRewards(msg.sender);
        }
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
    function poke() external nonReentrant {
        IBloomPool lastCreatedPool = _getLatestPool();
        IBloomPool.State currentState = lastCreatedPool.state();

        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            _autoMintTBY(lastCreatedPool);
        }

        if (_isEligibleForAdjustment(currentState)) {
            _adjustRemainingBalance(lastCreatedPool);
        }

        // If we haven't updated the values of TBYs in 12 hours, update it now
        if (block.timestamp - _lastRateUpdate >= 12 hours) {
            _lastRateUpdate = block.timestamp;
            _setTotalUsd(_getCurrentTbyValue() + _remainingBalance * _scalingFactor);
            _rewardManager.distributePokeRewards(msg.sender);
        }
    }

    /// @inheritdoc IStTBY
    function setNftTrustedRemote(uint16 remoteChainId, bytes calldata path) external onlyOwner {
        _redemptionNFT.setTrustedRemote(remoteChainId, path);
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
    function getExchangeRateRegistry() external view returns (IExchangeRateRegistry) {
        return _registry;
    }

    /// @inheritdoc IStTBY
    function getStakeupStaking() external view returns (IStakeupStaking) {
        return _stakeupStaking;
    }

    /// @inheritdoc IStTBY
    function getRewardManager() external view returns (IRewardManager) {
        return _rewardManager;
    }

    /// @inheritdoc IStTBY
    function getRedemptionNFT() external view returns (RedemptionNFT) {
        return _redemptionNFT;
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
     * @param token Token being deposited
     * @param amount The amount of tokens being deposited
     * @param isTby True if the token being deposited is a TBY
     */
    function _deposit(address token, uint256 amount, bool isTby) internal {   
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
            amountScaled = _registry.getExchangeRate(token).mulWad(amountScaled); 
        }

        uint256 sharesAmount = getSharesByUsd(amountScaled - mintFee);

        _mintShares(msg.sender, sharesAmount);
        _mintShares(address(_stakeupStaking), sharesFeeAmount);
        _stakeupStaking.processFees();

        uint256 mintRewardsRemaining = _mintRewardsRemaining;

        if (mintRewardsRemaining > 0) {
            uint256 eligibleAmount = Math.min(amountScaled, mintRewardsRemaining);
            _mintRewardsRemaining -= eligibleAmount;
            _rewardManager.distributeMintRewards(msg.sender, eligibleAmount);
        }

        _setTotalUsd(_getTotalUsd() + amountScaled);

        emit Deposit(msg.sender, token, amount, sharesAmount);
    }

    /**
     * @notice Redeems stTBY in exchange for underlying tokens
     * @param stTBYAmount Amount of stTBY to redeem
     * @return uint256 The tokenId of the redemption NFT
     */
    function _redeemStTBY(uint256 stTBYAmount) internal returns (uint256) {
        if (stTBYAmount == 0) revert ParameterOutOfBounds();

        uint256 shares = getSharesByUsd(stTBYAmount);
        
        (uint256 redemptonId, uint256 amountRedeemed) = _redeem(msg.sender, shares, stTBYAmount);

        emit Redeemed(msg.sender, shares, amountRedeemed);

        return redemptonId;
    }

    function _redeem(
        address account,
        uint256 shares,
        uint256 underlyingAmount
    )
        internal returns (uint256 redemptionId, uint256 amountRedeemed)
    {
        if (balanceOf(account) < underlyingAmount) revert InsufficientBalance();

        uint256 redeemFee = (shares * redeemBps) / BPS;

        if (redeemFee > 0) {
            shares -= redeemFee;
            uint256 redeemFeeAmount = getUsdByShares(redeemFee);
            underlyingAmount -= redeemFeeAmount;

            _transferShares(account, address(_stakeupStaking), redeemFee);
            _stakeupStaking.processFees();

            emit FeeCaptured(FeeType.Redeem, redeemFee);
        }

        _transferShares(account, address(_redemptionNFT), shares);

        redemptionId = _mintRedemptionNFT(account, shares);

        return (redemptionId, underlyingAmount);
    }

    /**
     * @notice Process the proceeds of TBYs and pay fees to Stakeup
     *   Staking
     * @param proceeds Proceeds in underlying tokens
     * @param yield Yield gained from TBY
     */
    function _processProceeds(uint256 proceeds, uint256 yield) internal {
        uint256 underlyingGains = yield * _scalingFactor;

        uint256 performanceFee = underlyingGains * performanceBps / BPS;

        if (performanceFee > 0) {
            uint256 sharesFeeAmount = getSharesByUsd(performanceFee);

            _mintShares(address(_stakeupStaking), sharesFeeAmount);
            _stakeupStaking.processFees();

            emit FeeCaptured(FeeType.Performance, sharesFeeAmount);
        }

        if (proceeds > 0) {
            _remainingBalance += proceeds;
        }

        _setTotalUsd(_getCurrentTbyValue() + _remainingBalance * _scalingFactor);
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     * @param pool The latest Bloom pool
     * @return uint256 Amount of USDC auto staked into the pool
     */
    function _autoMintTBY(IBloomPool pool) internal returns (uint256) {
        uint256 underlyingBalance = _underlyingToken.balanceOf(address(this));

        if (underlyingBalance > 0) {
            uint256 accountedBalance = _remainingBalance;
            uint256 unregisteredBalance = underlyingBalance - accountedBalance;
            
            delete _remainingBalance;

            _underlyingToken.safeApprove(address(pool), underlyingBalance);
            pool.depositLender(underlyingBalance);

            _lastDepositAmount += underlyingBalance;

            uint256 scaledUnregisteredBalance = unregisteredBalance * _scalingFactor;

            _setTotalUsd(_getTotalUsd() + scaledUnregisteredBalance);

            emit TBYAutoMinted(address(pool), underlyingBalance);
        }

        return underlyingBalance;
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
     * @notice Check if the pool is eligible for adjustment
     * @param state Pool state
     * @return bool True if the pool is in a state that allows for adjustment
     */
    function _isEligibleForAdjustment(IBloomPool.State state) internal pure returns (bool) {
        return state != IBloomPool.State.Commit
            && state != IBloomPool.State.PendingPreHoldSwap
            && state != IBloomPool.State.FinalWithdraw
            && state != IBloomPool.State.EmergencyExit;
    }

    /**
     * @notice Adjust the remaining balance to account for the difference between
     * the last deposit amount and the current balance of the latest TBYs
     * @param pool The latest Bloom pool
     * @return uint256 The difference between deposit amount and current balance
     */
    function _adjustRemainingBalance(IBloomPool pool) internal returns (uint256) {
        uint256 depositDifference;
        uint256 latestTbyBalance = IERC20(address(pool)).balanceOf(address(this));

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
     * @notice Creates a withdrawal request and mints a redemption NFT to 
     * the redeemer
     * @param account The address of the account redeeming their stTBY
     * @param shares The amount of shares to redeem
     */
    function _mintRedemptionNFT(address account, uint256 shares) internal returns (uint256) {
        return _redemptionNFT.addWithdrawalRequest(account, shares);
    }
    
    /**
     * @notice Calculates the current value of all TBYs that are staked in stTBY
     */
    function _getCurrentTbyValue() internal view returns (uint256) {
        address[] memory tokens = _registry.getActiveTokens();
        uint256 length = tokens.length;

        uint256 usdValue;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));
            usdValue += tokenBalance
                .rawMul(_scalingFactor)
                .mulWad(_registry.getExchangeRate(tokens[i]));
        }

        return usdValue;
    }
}
