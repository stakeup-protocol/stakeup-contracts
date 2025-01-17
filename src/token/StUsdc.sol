// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBloomRouter} from "@bloom-v2/interfaces/IBloomRouter.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
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
    uint256 internal _highWaterMark;

    // ================== Immutables ===================
    /// @dev Underlying token
    IERC20 private immutable _asset;

    /// @dev bloomRouter Contract
    IBloomRouter private immutable _bloomRouter;

    /// @dev StakeUp Staking Contract
    IStakeUpStaking private immutable _stakeupStaking;

    /// @dev SUP Token Contract
    IStakeUpToken private immutable _stakeupToken;

    /// @dev Scaling factor for underlying token
    uint256 private immutable _scalingFactor;

    /// @dev Underlying token decimals
    uint8 private immutable _assetDecimals;

    // ================== Modifiers ====================

    /**
     * @notice Updates the state of the contract by harvesting matured TBYs,
     * autocompounding rewards and updating totalUsd
     */
    modifier updateState() {
        harvest();
        _;
    }

    // ================== Constructor ==================

    constructor(address asset_, address bloomRouter_, address stakeupStaking_, address owner) StUsdcLite(owner) {
        require(
            asset_ != address(0) && bloomRouter_ != address(0) && stakeupStaking_ != address(0), Errors.ZeroAddress()
        );

        _asset = IERC20(asset_);
        _assetDecimals = IERC20Metadata(asset_).decimals();

        require(IBloomRouter(bloomRouter_).asset() == asset_, Errors.InvalidAsset());
        _bloomRouter = IBloomRouter(bloomRouter_);

        _stakeupStaking = IStakeUpStaking(stakeupStaking_);
        _stakeupToken = IStakeUpStaking(stakeupStaking_).stakupToken();

        _scalingFactor = 10 ** (18 - _assetDecimals);

        // On the first redemption we will increment this value to overflow and start at 0.
        _lastRedeemedTbyId = type(uint256).max;
    }

    // =================== External Functions ==================

    /// @inheritdoc IStUsdc
    function depositAsset(uint256 amount) external nonReentrant updateState returns (uint256 amountMinted) {
        require(amount > 0, Errors.ZeroAmount());
        amountMinted = amount * _scalingFactor;

        _deposit(amountMinted);
        emit AssetDeposited(msg.sender, amount);
        _openLendOrder(amount);
    }

    /// @inheritdoc IStUsdc
    function redeemStUsdc(uint256 amount) external nonReentrant updateState returns (uint256 assetAmount) {
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
    function harvest() public nonReentrant {
        IBloomRouter router = _bloomRouter;

        _harvest(router);
        _autoLendAsset(router);
        _accrueYield(router);
    }

    // =================== Internal Functions ===================

    /**
     * @notice Harvests the next TbyId that is ready for redemption.
     * @param router The Bloom router contract
     */
    function _harvest(IBloomRouter router) internal {
        uint256 tbyId = lastRedeemedTbyId();
        // Because we start at type(uint256).max, we need to increment and overflow to 0.
        unchecked {
            tbyId++;
        }

        // If the pool is not found, it means that TBY hasnt been created yet.
        address pool = router.poolFromTbyId(tbyId);
        if (pool == address(0)) return;

        // If there are no rewards, no need to redeem.
        uint256 rewards = IBloomPool(pool).lenderReturns(tbyId);
        uint256 amount = ERC1155(pool).balanceOf(address(this), tbyId);

        // If there are no rewards and our balance is 0, then we can skip redeeming.
        if (rewards == 0) {
            // Make sure we are covering the case where we are still in the swap buffer period, so that we dont skip
            //      redeeming a TBY that could be minted to us in the future.
            if (amount == 0) {
                uint256 start = IBloomPool(pool).tbyMaturity(tbyId).start;
                uint256 swapBuffer = IBloomPool(pool).swapBuffer();
                if (block.timestamp > start + swapBuffer) {
                    _lastRedeemedTbyId = tbyId;
                    return;
                }
                return;
            }
        }

        // Since users can't deposit TBYs that are redeemable, we can update the last redeemed TBY ID.
        _lastRedeemedTbyId = tbyId;

        // If the contracts balance is 0, then we can skip redeeming.
        if (amount == 0) return;

        // Redeem TBYs
        router.redeemLender(tbyId, amount);
    }

    /**
     * @notice Auto lend USDC by opening a lend order in the Bloom router
     * @dev Auto lend feature can only be invoked every 24 hours
     * @param router The Bloom router contract
     */
    function _autoLendAsset(IBloomRouter router) internal {
        uint256 amount = _asset.balanceOf(address(this));
        if (amount > 0) {
            _asset.safeApprove(address(router), amount);
            router.lendOrder(amount);
            emit AssetAutoLent(amount);
        }
    }

    /**
     * @notice Calculate the protocol value of assets and TBYs backed by the contract and updates the totalUsd.
     * @param router The Bloom router contract
     */
    function _accrueYield(IBloomRouter router) internal {
        uint256 protocolValue = _protocolValue(router);
        uint256 totalSupply = totalSupply();

        if (protocolValue > totalSupply) {
            uint256 performanceFee = _calculateFee(protocolValue, totalSupply);
            _setTotalUsd(protocolValue - performanceFee);
            _processFee(performanceFee);
        } else {
            _setTotalUsd(protocolValue);
        }
    }

    /**
     * @notice Open a lend order in the Bloom router.
     * @param amount The amount of liquidity to lend.
     */
    function _openLendOrder(uint256 amount) internal {
        IBloomRouter router = _bloomRouter;
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _asset.safeApprove(address(router), amount);
        _bloomRouter.lendOrder(amount);
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
        IBloomRouter router = _bloomRouter;
        uint256 amountOpen = router.amountOpen(address(this));

        // Cancel open lend orders if there are any
        if (amountOpen > 0) {
            uint256 killAmount = Math.min(amountOpen, amount);
            router.killOpenOrder(killAmount);
            amount -= killAmount;
        }
    }

    /**
     * @notice Calculate the protocol value of assets and TBYs backed by the contract.
     * @return value The protocol value of assets and TBYs in USD scaled to 1e18.
     */
    function _protocolValue(IBloomRouter router) internal view returns (uint256 value) {
        uint256 startingId = lastRedeemedTbyId();
        // Because we start at type(uint256).max, we need to increment and overflow to 0.
        unchecked {
            startingId++;
        }
        uint256 lastMintedId = router.lastMintedId();
        if (lastMintedId == type(uint256).max) return 0;
        uint256[] memory tbyIds = _generateConsecutiveIds(startingId, lastMintedId);

        value = router.lenderBatchTvl(address(this), tbyIds, true);
        value *= _scalingFactor;
    }

    /**
     * @notice Calculate the performance fee based on the protocol value, total supply, and high water mark.
     * @param protocolValue The protocol value of assets and TBYs in USD scaled to 1e18.
     * @param totalSupply The total amount of stUsdc shares in circulation on all chains.
     * @return fee The performance fee in USD scaled to 1e18.
     */
    function _calculateFee(uint256 protocolValue, uint256 totalSupply) internal returns (uint256 fee) {
        uint256 hwm = _highWaterMark;
        uint256 usdPerShare = protocolValue.divWad(totalSupply);

        if (usdPerShare > hwm) {
            _updateHighWaterMark(hwm, usdPerShare);
            uint256 diff = usdPerShare - hwm;
            uint256 newYield = diff.mulWad(totalSupply);
            fee = (newYield * Constants.PERFORMANCE_BPS) / Constants.BPS_DENOMINATOR;
        }
    }

    /**
     * @notice Generate an array of consecutive TBY IDs.
     * @param start The starting TBY ID.
     * @param end The ending TBY ID.
     * @return ids The array of TBY IDs.
     */
    function _generateConsecutiveIds(uint256 start, uint256 end) internal pure returns (uint256[] memory ids) {
        require(end >= start, Errors.InvalidStartEnd());

        uint256 len = end - start + 1;
        ids = new uint256[](len);
        for (uint256 i = 0; i < len; ++i) {
            ids[i] = start + i;
        }
    }

    /**
     * @notice Updates the high water mark.
     * @param oldHighWaterMark The old high water mark.
     * @param newHighWaterMark The new high water mark.
     */
    function _updateHighWaterMark(uint256 oldHighWaterMark, uint256 newHighWaterMark) internal {
        _highWaterMark = newHighWaterMark;
        emit HighWaterMarkUpdated(oldHighWaterMark, newHighWaterMark);
    }

    // =================== View Functions ===================

    /// @inheritdoc IStUsdc
    function asset() external view returns (IERC20) {
        return _asset;
    }

    /// @inheritdoc IStUsdc
    function bloomRouter() external view returns (IBloomRouter) {
        return _bloomRouter;
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
    function highWaterMark() external view returns (uint256) {
        return _highWaterMark;
    }
}
