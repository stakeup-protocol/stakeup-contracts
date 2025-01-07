// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {IBorrowModule} from "@bloom-v2/interfaces/IBorrowModule.sol";

import {ERC1155} from "solady/tokens/ERC1155.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {StakeUpConstants as Constants} from "@StakeUp/helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {StUsdcLite} from "@StakeUp/token/StUsdcLite.sol";

import {IStakeUpStaking} from "@StakeUp/interfaces/IStakeUpStaking.sol";
import {IStakeUpToken} from "@StakeUp/interfaces/IStakeUpToken.sol";
import {IStUsdc} from "@StakeUp/interfaces/IStUsdc.sol";

/// @title Staked TBY Contract
contract StUsdc is IStUsdc, StUsdcLite, ReentrancyGuard, ERC1155TokenReceiver {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // =================== Storage ===================
    /// @dev The total amount of stUsdc shares in circulation on all chains
    uint256 internal _globalShares;

    /// @dev Last redeemed tbyId
    uint256 internal _lastRedeemedTbyId;

    /// @dev Highest usdPerShare value used to calculate the performance fee
    uint256 internal _highestUsdPerShare;

    // ================== Immutables ===================
    /// @dev Underlying token
    IERC20 private immutable _asset;

    /// @dev TBY Contract
    ERC1155 private immutable _tby;

    /// @dev BloomPool Contract
    IBloomPool private immutable _bloomPool;

    /// @dev StakeUp Staking Contract
    IStakeUpStaking private immutable _stakeupStaking;

    /// @dev SUP Token Contract
    IStakeUpToken private immutable _stakeupToken;

    /// @dev Scaling factor for underlying token
    uint256 private immutable _scalingFactor;

    /// @dev Underlying token decimals
    uint8 private immutable _assetDecimals;

    // ================== Constructor ==================

    constructor(address asset_, address bloomPool_, address stakeupStaking_, address owner) StUsdcLite(owner) {
        require(asset_ != address(0) && stakeupStaking_ != address(0), Errors.ZeroAddress());

        _asset = IERC20(asset_);
        _assetDecimals = IERC20Metadata(asset_).decimals();

        require(IBloomPool(bloomPool_).asset() == asset_, Errors.InvalidAsset());
        _bloomPool = IBloomPool(bloomPool_);
        _tby = ERC1155(IBloomPool(bloomPool_).tby());

        _stakeupStaking = IStakeUpStaking(stakeupStaking_);
        _stakeupToken = IStakeUpStaking(stakeupStaking_).stakupToken();

        _scalingFactor = 10 ** (18 - _assetDecimals);

        // On the first redemption we will increment this value to overflow and start at 0.
        _lastRedeemedTbyId = type(uint256).max;
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
        _setTotalUsd(_totalUsd - amount);
        _globalShares -= shares;

        emit Redeemed(msg.sender, shares, assetAmount);
        _asset.safeTransfer(msg.sender, assetAmount);
    }

    /// @inheritdoc IStUsdc
    function poke() external payable nonReentrant {
        uint256 currentTimestamp = block.timestamp;
        if (currentTimestamp - _lastRateUpdate < Constants.ONE_DAY) return;
        _lastRateUpdate = currentTimestamp;

        IBloomPool pool = _bloomPool;

        // Harvest matured TBYs
        _harvest();

        // Open a lend order in the Bloom Pool to auto-compound USDC
        _autoLendAsset(pool);

        // Calculate the value of USDC and TBYs backed by the contract
        uint256 protocolValue = _protocolValue(pool);
        // Potentially drip over next 24 hours.
        uint256 yieldGenerated = protocolValue - totalSupply();
        uint256 performanceFee = (yieldGenerated * Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;
        _processFee(performanceFee);
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
        _setTotalUsd(_totalUsd + amount);
    }

    /**
     * @notice Distributes fees to StakeUp Staking
     * @param fee The fee amount in USD scaled to 1e18.
     */
    function _processFee(uint256 fee) internal {
        if (fee > 0) {
            uint256 sharesFeeAmount = sharesByUsd(fee);
            _mintShares(address(_stakeupStaking), sharesFeeAmount);
            _setTotalUsd(_totalUsd + fee);

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
            address module = pool.tbyModule(i);
            value += IBorrowModule(module).getRate(i).mulWad(_tby.balanceOf(address(this), i));
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

        address module = pool.tbyModule(tbyId);
        uint256 rewards = IBorrowModule(module).lenderReturns(tbyId);
        if (rewards == 0) return;

        // Since users can't deposit TBYs that are redeemable, we can update the last redeemed TBY ID.
        _lastRedeemedTbyId = tbyId;

        uint256 amount = _tby.balanceOf(address(this), tbyId);
        if (amount == 0) return;

        // Redeem TBYs
        pool.redeemLender(tbyId, amount);
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
}
