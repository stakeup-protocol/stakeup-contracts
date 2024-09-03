// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

    /// @dev Last redeemed tbyId
    uint256 internal _lastRedeemedTbyId;

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
        _tby = ERC1155(IBloomPool(bloomPool_).tby());

        _stakeupStaking = IStakeUpStaking(stakeupStaking_);
        _stakeupToken = IStakeUpStaking(stakeupStaking_).stakupToken();
        _wstUsdc = IWstUsdc(wstUsdc_);

        _scalingFactor = 10 ** (18 - _assetDecimals);
        _startTimestamp = block.timestamp;
        _lastRateUpdate = block.timestamp;

        _pokeRewardsRemaining = Constants.POKE_REWARDS;
        _mintRewardsRemaining = StakeUpMintRewardLib._getMintRewardAllocation();

        // On the first redemption we will increment this value, so we start at 0.
        _lastRedeemedTbyId = type(uint256).max;
    }

    // =================== Functions ==================

    /// @inheritdoc IStUsdc
    function depositTby(uint256 tbyId, uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        IBloomPool pool = _bloomPool;
        require(amount > 0, Errors.ZeroAmount());
        require(!pool.isTbyRedeemable(tbyId), "TBY is redeemable");
        require(tbyId > lastRedeemedTbyId(), "TBY has already been redeemed");

        // If the token is a TBY, we need to get the current exchange rate of the token
        //     to accurately calculate the amount of stUsdc to mint.
        amountMinted = pool.getRate(tbyId).mulWad(amount);
        _deposit(amountMinted);
        emit TbyDeposited(msg.sender, tbyId, amount, amountMinted);
        _tby.safeTransferFrom(msg.sender, address(this), tbyId, amount, "");
    }

    /// @inheritdoc IStUsdc
    function depositAsset(uint256 amount) external nonReentrant returns (uint256 amountMinted) {
        IBloomPool pool = _bloomPool;
        require(amount > 0, Errors.ZeroAmount());
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        amountMinted = amount * _scalingFactor;
        _deposit(amountMinted);
        emit AssetDeposited(msg.sender, amount);
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _asset.safeApprove(address(pool), amount);
        pool.lendOrder(amount);
    }

    /// @inheritdoc IStUsdc
    function redeemStUsdc(uint256 amount) external nonReentrant returns (uint256 assetAmount) {
        require(amount > 0, Errors.ZeroAmount());
        require(balanceOf(msg.sender) >= amount, Errors.InsufficientBalance());
        require(_mintRewardsRemaining == 0, Errors.RedemptionsNotAllowed());

        uint256 shares = sharesByUsd(amount);
        assetAmount = amount / _scalingFactor;

        if (_asset.balanceOf(address(this)) < assetAmount) {
            _tryOrderCancellation(assetAmount);
            require(_asset.balanceOf(address(this)) >= assetAmount, Errors.InsufficientBalance());
        }

        _burnShares(msg.sender, shares);
        _setTotalUsd(_getTotalUsd() - amount);
        _globalShares -= shares;

        emit Redeemed(msg.sender, shares, assetAmount);
        _asset.safeTransfer(msg.sender, assetAmount);
    }

    /// @inheritdoc IStUsdc
    function harvest() external override nonReentrant returns (uint256 assetsWithdrawn) {
        IBloomPool pool = _bloomPool;
        uint256 lastRateUpdate = _lastRateUpdate;
        require(block.timestamp - lastRateUpdate < 24 hours, Errors.RateUpdateNeeded());

        uint256 tbyId = lastRedeemedTbyId();
        // Because we start at type(uint256).max, we need to increment and overflow to 0.
        unchecked {
            tbyId++;
        }
        bool isRedeemable = pool.isTbyRedeemable(tbyId);
        uint256 amount = _tby.balanceOf(address(this), tbyId);

        if (!isRedeemable) return 0;
        if (isRedeemable && amount == 0) {
            _lastRedeemedTbyId = tbyId;
            return 0;
        }

        assetsWithdrawn = pool.redeemLender(tbyId, amount);
        uint256 yieldScaled = (assetsWithdrawn - amount) * _scalingFactor;
        _processYield(yieldScaled);
        _distributePokeRewards();
    }

    /// @inheritdoc IStUsdc
    function poke() external nonReentrant {
        IBloomPool pool = _bloomPool;
        uint256 lastUpdate = _lastRateUpdate;
        uint256 currentTimestamp = block.timestamp;
        if (currentTimestamp - lastUpdate >= 24 hours) {
            _lastRateUpdate = currentTimestamp;
            // Open a lend order in the Bloom Pool to auto-compound USDC
            _autoLendAsset(pool);

            // Calculate the value of USDC and TBYs backed by the contract
            //    and update the yield per share.
            uint256 protocolValue = _protocolValue(pool);
            uint256 usdPerShare = protocolValue.divWad(_globalShares);
            _setUsdPerShare(usdPerShare);

            // Distribute rewards to the user who poked the contract
            _distributePokeRewards();
        }
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

    /**
     * @notice Accounting logic for handling underlying asset and tby deposits.
     * @param amount The amount stUsdc being minted.
     */
    function _deposit(uint256 amount) internal {
        uint256 sharesAmount = sharesByUsd(amount);
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
     * @param yield The amount of yield accrued scaled to 1e18
     */
    function _processYield(uint256 yield) internal {
        uint256 performanceFee = (yield * Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;

        if (performanceFee > 0) {
            uint256 sharesFeeAmount = sharesByUsd(performanceFee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);
            _globalShares += sharesFeeAmount;
            emit FeeCaptured(sharesFeeAmount);
        }
        _stakeupStaking.processFees();
    }

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
        uint256 startingId = lastRedeemedTbyId() + 1;
        uint256 lastMintedId = pool.lastMintedId();
        for (uint256 i = startingId; i <= lastMintedId; ++i) {
            value += pool.getRate(i).mulWad(_tby.balanceOf(address(this), i));
        }
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
}
