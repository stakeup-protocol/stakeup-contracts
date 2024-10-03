// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StakeUpConstants as Constants} from "@StakeUp/helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {StUsdcLite} from "@StakeUp/token/StUsdcLite.sol";
import {StakeUpRewardMathLib} from "@StakeUp/rewards/lib/StakeUpRewardMathLib.sol";
import {StakeUpMintRewardLib} from "@StakeUp/rewards/lib/StakeUpMintRewardLib.sol";

import {IStakeUpStaking} from "@StakeUp/interfaces/IStakeUpStaking.sol";
import {IStakeUpToken} from "@StakeUp/interfaces/IStakeUpToken.sol";
import {IStUsdc} from "@StakeUp/interfaces/IStUsdc.sol";
import {IWstUsdc} from "@StakeUp/interfaces/IWstUsdc.sol";

/// @title Staked TBY Contract
contract StUsdc is IStUsdc, StUsdcLite, ReentrancyGuard, ERC1155TokenReceiver {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstUsdc;

    // =================== Storage ===================
    /// @dev The total amount of stUsdc shares in circulation on all chains
    uint256 internal _globalShares;

    /// @dev Mint rewards remaining
    uint256 internal _mintRewardsRemaining;

    /// @notice Amount of rewards remaining to be distributed to users for poking the contract
    uint256 private _pokeRewardsRemaining;

    /// @dev Last redeemed tbyId
    uint256 internal _lastRedeemedTbyId;

    /// @dev Highest usdPerShare value used to calculate the performance fee
    uint256 internal _highestUsdPerShare;

    /// @dev The pending fee to be distributed during the next poke
    uint256 internal _pendingFee;

    // ================== Immutables ===================
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

    /// @dev Deployment timestamp
    uint256 private immutable _startTimestamp;

    /// @dev Scaling factor for underlying token
    uint256 private immutable _scalingFactor;

    /// @dev Underlying token decimals
    uint8 private immutable _assetDecimals;

    // ================== Constructor ==================

    constructor(
        address asset_,
        address bloomPool_,
        address stakeupStaking_,
        address wstUsdc_,
        address layerZeroEndpoint,
        address bridgeOperator
    ) StUsdcLite(layerZeroEndpoint, bridgeOperator) {
        require(asset_ != address(0) && stakeupStaking_ != address(0) && wstUsdc_ != address(0), Errors.ZeroAddress());

        _asset = IERC20(asset_);
        _assetDecimals = IERC20Metadata(asset_).decimals();

        require(IBloomPool(bloomPool_).asset() == asset_, Errors.InvalidAsset());
        _bloomPool = IBloomPool(bloomPool_);
        _tby = ERC1155(IBloomPool(bloomPool_).tby());

        _stakeupStaking = IStakeUpStaking(stakeupStaking_);
        _stakeupToken = IStakeUpStaking(stakeupStaking_).stakupToken();
        _wstUsdc = IWstUsdc(wstUsdc_);

        _scalingFactor = 10 ** (18 - _assetDecimals);
        _startTimestamp = block.timestamp;

        _pokeRewardsRemaining = Constants.POKE_REWARDS;
        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();

        // On the first redemption we will increment this value to overflow and start at 0.
        _lastRedeemedTbyId = type(uint256).max;
        _highestUsdPerShare = Math.WAD;
    }

    // =================== Functions ==================

    /// @inheritdoc IStUsdc
    function depositAsset(uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        require(amount > 0, Errors.ZeroAmount());
        amountMinted = amount * _scalingFactor;

        _deposit(amountMinted);
        emit AssetDeposited(msg.sender, amount);
        _openLendOrder(amount);
    }

    /// @inheritdoc IStUsdc
    function depositTby(uint256 tbyId, uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        IBloomPool pool = _bloomPool;
        require(amount > 0, Errors.ZeroAmount());
        require(!pool.isTbyRedeemable(tbyId), Errors.RedeemableTbyNotAllowed());
        // If the token is a TBY, we need to get the current exchange rate of the token
        //     to accurately calculate the amount of stUsdc to mint.
        amountMinted = pool.getRate(tbyId).mulWad(amount) * _scalingFactor;

        _deposit(amountMinted);
        // Calculate & mint SUP mint rewards to users.
        _mintRewards(pool, tbyId, amount);

        emit TbyDeposited(msg.sender, tbyId, amount, amountMinted);
        _tby.safeTransferFrom(msg.sender, address(this), tbyId, amount, "");
    }

    /// @inheritdoc IStUsdc
    function redeemStUsdc(uint256 amount) external nonReentrant returns (uint256 assetAmount) {
        require(amount > 0, Errors.ZeroAmount());
        require(balanceOf(msg.sender) >= amount, Errors.InsufficientBalance());

        uint256 shares = sharesByUsd(amount);
        assetAmount = amount / _scalingFactor;

        uint256 assetBalance = _asset.balanceOf(address(this));
        if (assetBalance < assetAmount) {
            uint256 amountNeeded = assetAmount - assetBalance;
            _tryOrderCancellation(amountNeeded);
            uint256 newAssetBalance = _asset.balanceOf(address(this));
            require(newAssetBalance >= assetAmount, Errors.InsufficientBalance());
        }

        _burnShares(msg.sender, shares);
        _setTotalUsdFloor(_totalUsdFloor - amount);
        _globalShares -= shares;

        emit Redeemed(msg.sender, shares, assetAmount);
        _asset.safeTransfer(msg.sender, assetAmount);
    }

    /// @inheritdoc IStUsdc
    function poke(LzSettings calldata settings) external payable nonReentrant {
        uint256 currentTimestamp = block.timestamp;
        uint256 lastUpdate = _lastRateUpdate;
        if (currentTimestamp - lastUpdate < Constants.ONE_DAY) return;

        IBloomPool pool = _bloomPool;

        // Open a lend order in the Bloom Pool to auto-compound USDC
        _autoLendAsset(pool);

        // Calculate the value of USDC and TBYs backed by the contract
        uint256 globalShares_ = _globalShares;
        uint256 protocolValue = _protocolValue(pool);
        uint256 newUsdPerShare = protocolValue.divWad(globalShares_);
        uint256 lastUsdPerShare = _lastUsdPerShare;
        uint256 prevFee = _pendingFee;

        if (newUsdPerShare > lastUsdPerShare) {
            uint256 newPendingFee;
            uint256 highestUsdPerShare = _highestUsdPerShare;
            if (newUsdPerShare > highestUsdPerShare) {
                // Calculate performance fee
                uint256 yieldPerShare = newUsdPerShare - highestUsdPerShare;
                newPendingFee = _calculateFee(yieldPerShare, globalShares_);
                _highestUsdPerShare = newUsdPerShare;
            }
            // Calculate the new total value of the protocol for users
            uint256 userValue = protocolValue - newPendingFee;
            newUsdPerShare = userValue.divWad(globalShares_);
            _pendingFee = newPendingFee;
        }

        // Update USD per share to reflect the new value
        _setUsdPerShare(newUsdPerShare, currentTimestamp);

        uint256 peerLength = _peerEids.length;
        if (peerLength != 0) {
            uint256 lzFee = settings.fee.nativeFee;
            require(msg.value >= lzFee, Errors.InvalidMsgValue());
            _keeper.sync{value: lzFee}(
                newUsdPerShare, currentTimestamp, _peerEids, settings.options, settings.refundRecipient
            );
        }

        // If their is a previous pending fee, we need to distribute it to StakeUpStaking
        if (prevFee != 0) {
            _processFee(prevFee);
        }

        // Harvest matured TBYs and distribute rewards
        _harvest();
        _distributePokeRewards();
    }

    /**
     * @notice Calculate the performance fee for the protocol
     * @param yieldPerShare The yield per share
     * @param globalShares_ The total number of shares
     * @return The performance fee that will be distributed to StakeUpStaking
     */
    function _calculateFee(uint256 yieldPerShare, uint256 globalShares_) private pure returns (uint256) {
        uint256 totalYield = yieldPerShare.mulWad(globalShares_);
        return (totalYield * Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;
    }

    /**
     * @notice Open a lend order in the Bloom Pool.
     * @param amount The amount of liquidity to lend.
     */
    function _openLendOrder(uint256 amount) internal {
        IBloomPool pool = _bloomPool;
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _asset.safeApprove(address(pool), amount);
        pool.lendOrder(amount);
    }

    /**
     * @notice Accounting logic for handling underlying asset and tby deposits.
     * @param amount The amount stUsdc being minted.
     */
    function _deposit(uint256 amount) internal {
        uint256 sharesAmount = sharesByUsd(amount);
        if (sharesAmount == 0) revert Errors.ZeroAmount();

        _mintShares(msg.sender, sharesAmount);
        _globalShares += sharesAmount;
        _setTotalUsdFloor(_totalUsdFloor + amount);
    }

    /**
     * @notice Mints SUP rewards to the depositor
     * @dev Mint rewards are only eligible for users who deposit TBYs into the contract
     * @param pool The Bloom Pool contract
     * @param tbyId The TBY ID
     * @param amount The amount of TBYs deposited
     */
    function _mintRewards(IBloomPool pool, uint256 tbyId, uint256 amount) internal {
        uint256 mintRewardsRemaining = _mintRewardsRemaining;
        if (mintRewardsRemaining > 0) {
            uint256 maxRewards = _calculateRewards(pool, tbyId, amount);
            uint256 eligibleAmount = Math.min(maxRewards, mintRewardsRemaining);
            _mintRewardsRemaining -= eligibleAmount;
            _stakeupToken.mintRewards(msg.sender, eligibleAmount);
        }
    }

    /**
     * @notice Distributes fees to StakeUp Staking
     * @param fee The fee amount in USD scaled to 1e18.
     */
    function _processFee(uint256 fee) internal {
        if (fee > 0) {
            uint256 sharesFeeAmount = sharesByUsd(fee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);
            _setTotalUsdFloor(_totalUsdFloor + fee);

            _globalShares += sharesFeeAmount;
            emit FeeCaptured(sharesFeeAmount);
            _stakeupStaking.processFees();
        }
    }

    /**
     * @notice Attempt to cancel an open lend order and/or matched orders to free access liquidity.
     * @param amount The amount of liquidity needed.
     */
    function _tryOrderCancellation(uint256 amount) internal {
        IBloomPool pool = _bloomPool;
        uint256 amountOpen = pool.amountOpen(address(this));

        // Cancel open lend orders if there are any
        if (amountOpen > 0) {
            uint256 killAmount = Math.min(amountOpen, amount);
            pool.killOpenOrder(killAmount);
            amount -= killAmount;
        }

        // If more liquidity is needed, cancel matched orders
        if (amount > 0) {
            uint256 amountMatched = pool.amountMatched(address(this));
            if (amountMatched > 0) {
                uint256 killAmount = Math.min(amountMatched, amount);
                pool.killMatchOrder(killAmount);
                amount -= killAmount;
            }
        }
    }

    /**
     * @notice Auto lend USDC by opening a lend order in the Bloom Pool
     * @dev Auto lend feature can only be invoked every 24 hours
     * @param pool The Bloom Pool contract
     */
    function _autoLendAsset(IBloomPool pool) internal {
        uint256 amount = _asset.balanceOf(address(this));
        if (amount > 0) {
            _asset.safeApprove(address(pool), amount);
            pool.lendOrder(amount);
            emit AssetAutoLent(amount);
        }
    }

    /**
     * @notice Calculate the protocol value of assets and TBYs backed by the contract.
     * @return value The protocol value of assets and TBYs in USD scaled to 1e18.
     */
    function _protocolValue(IBloomPool pool) internal view returns (uint256 value) {
        value += pool.amountOpen(address(this));
        value += pool.amountMatched(address(this));
        value += _liveTbyValue(pool);
        value *= _scalingFactor;
    }

    /**
     * @notice Calculate the value of live TBYs backed by the contract.
     * @param pool The Bloom Pool contract.
     * @return value The value of live TBYs in USD in terms of the underlying asset.
     */
    function _liveTbyValue(IBloomPool pool) internal view returns (uint256 value) {
        uint256 startingId = lastRedeemedTbyId();
        // Because we start at type(uint256).max, we need to increment and overflow to 0.
        unchecked {
            startingId++;
        }
        uint256 lastMintedId = pool.lastMintedId();
        if (lastMintedId == type(uint256).max) return 0;
        for (uint256 i = startingId; i <= lastMintedId; ++i) {
            value += pool.getRate(i).mulWad(_tby.balanceOf(address(this), i));
        }
    }

    /// @notice Harvests the next TbyId that is ready for redemption.
    function _harvest() internal {
        IBloomPool pool = _bloomPool;
        uint256 tbyId = lastRedeemedTbyId();
        // Because we start at type(uint256).max, we need to increment and overflow to 0.
        unchecked {
            tbyId++;
        }
        bool isRedeemable = pool.isTbyRedeemable(tbyId);
        if (!isRedeemable) return;

        // Since users can't deposit TBYs that are redeemable, we can update the last redeemed TBY ID.
        _lastRedeemedTbyId = tbyId;

        uint256 amount = _tby.balanceOf(address(this), tbyId);
        if (amount == 0) return;

        // Redeem TBYs
        pool.redeemLender(tbyId, amount);
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

    /**
     * @notice Calculates the maximum amount of mint rewards for a user depositing TBYs
     * @dev There is an inverse relationship between the amount of time a TBY has been minted and the amount of rewards a user can earn.
     * @dev This calculation method is used in order to prevent users from gaming the rewards system.
     * @param pool The Bloom Pool contract
     * @param tbyId The TBY ID
     * @param amount The amount of TBYs deposited
     * @return The maximum rewards eligible for a user depositing TBYs
     */
    function _calculateRewards(IBloomPool pool, uint256 tbyId, uint256 amount) internal view returns (uint256) {
        IBloomPool.TbyMaturity memory maturity = pool.tbyMaturity(tbyId);

        uint256 timeElapsed = block.timestamp - maturity.start;
        uint256 percentMature = timeElapsed.divWad(maturity.end - maturity.start);
        percentMature = percentMature >= Math.WAD ? Math.WAD : percentMature;

        uint256 scaledAmount = amount * _scalingFactor;
        uint256 rewardsAbandoned = scaledAmount.mulWad(percentMature);

        return scaledAmount - rewardsAbandoned;
    }

    /// @inheritdoc IStUsdc
    function asset() external view returns (IERC20) {
        return _asset;
    }

    /// @inheritdoc IStUsdc
    function tby() external view returns (ERC1155) {
        return _tby;
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
    function stakeUpToken() external view returns (IStakeUpToken) {
        return _stakeupToken;
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
    function lastRedeemedTbyId() public view returns (uint256) {
        return _lastRedeemedTbyId;
    }

    /// @inheritdoc IStUsdc
    function pendingFee() external view returns (uint256) {
        return _pendingFee;
    }
}
