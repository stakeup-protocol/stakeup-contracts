// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IWstTBY} from "../interfaces/IWstTBY.sol";
import {StTBYBase} from "./StTBYBase.sol";

/**
 * @title Wrapped Staked TBY
 * @notice The non-rebasing, wrapped version of the stTBY token that accues yield from TBYs
 */
contract WstTBY is IWstTBY, ERC20 {
    // =================== Constants ===================

    /// @notice Instance of the stTBY contract
    IStTBY private immutable _stTBY;

    /// @notice Instance of the stTBY underlying token
    IERC20 private immutable _stTBYUnderlying;

    // ================== Constructor ==================

    constructor(address stTBY) ERC20("Wrapped staked TBY", "wstTBY") {
        _stTBY = IStTBY(stTBY);
        _stTBYUnderlying = IStTBY(stTBY).getUnderlyingToken();
    }

    // =================== Functions ===================

    /// @inheritdoc IWstTBY
    function wrap(uint256 stTBYAmount) external returns (uint256 wstTBYAmount) {
        wstTBYAmount = _mintWstTBY(stTBYAmount);

        ERC20(address(_stTBY)).transferFrom(
            msg.sender,
            address(this),
            stTBYAmount
        );
        return wstTBYAmount;
    }

    /// @inheritdoc IWstTBY
    function unwrap(uint256 wstTBYAmount) external returns (uint256) {
        uint256 stTBYAmount = _stTBY.getUsdByShares(wstTBYAmount);
        if (stTBYAmount == 0) revert Errors.ZeroAmount();

        _burn(msg.sender, wstTBYAmount);
        StTBYBase(address(_stTBY)).transferShares(msg.sender, wstTBYAmount);
        return stTBYAmount;
    }

    /// @inheritdoc IWstTBY
    function mintWstTBY(
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        override
        returns (
            uint256 amountMinted,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        _stageDeposit(address(_stTBYUnderlying), amount);

        (amountMinted, bridgingReceipt, msgReceipts) = _stTBY.depositUnderlying(
            amount,
            settings
        );
        amountMinted = _mintWstTBY(amountMinted);
    }

    /// @inheritdoc IWstTBY
    function mintWstTBY(
        address tby,
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        override
        returns (
            uint256 amountMinted,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        )
    {
        _stageDeposit(tby, amount);

        (amountMinted, bridgingReceipt, msgReceipts) = _stTBY.depositTby(
            tby,
            amount,
            settings
        );
        amountMinted = _mintWstTBY(amountMinted);
    }

    /// @inheritdoc IWstTBY
    function getWstTBYByStTBY(
        uint256 stTBYAmount
    ) external view returns (uint256) {
        return _stTBY.getSharesByUsd(stTBYAmount);
    }

    /// @inheritdoc IWstTBY
    function getStTBYByWstTBY(
        uint256 wstTBYAmount
    ) external view returns (uint256) {
        return _stTBY.getUsdByShares(wstTBYAmount);
    }

    /// @inheritdoc IWstTBY
    function stTBYPerToken() external view returns (uint256) {
        return _stTBY.getUsdByShares(1 ether);
    }

    /// @inheritdoc IWstTBY
    function tokensPerStTBY() external view returns (uint256) {
        return _stTBY.getSharesByUsd(1 ether);
    }

    /// @inheritdoc IWstTBY
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }

    /**
     * @notice Transfers the token to the wrapper contracts and sets approvals
     * @param token Address of the token being deposited into stTBY
     * @param amount The amount of tokens to deposit
     */
    function _stageDeposit(address token, uint256 amount) internal {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(_stTBY), amount);
    }

    /**
     * @notice Mint wstTBY to the user
     * @param amount The amount of stTBY to wrap
     */
    function _mintWstTBY(
        uint256 amount
    ) internal returns (uint256 wstTBYAmount) {
        wstTBYAmount = _stTBY.getSharesByUsd(amount);
        if (wstTBYAmount == 0) revert Errors.ZeroAmount();
        _mint(msg.sender, wstTBYAmount);
    }
}
