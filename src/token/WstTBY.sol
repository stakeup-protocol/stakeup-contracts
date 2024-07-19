// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {StTBYBase} from "./StTBYBase.sol";
import {WstTBYBase} from "./WstTBYBase.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IWstTBY} from "../interfaces/IWstTBY.sol";

/**
 * @title Wrapped Staked TBY
 * @notice The non-rebasing, wrapped version of the stTBY token that accues yield from TBYs
 */
contract WstTBY is IWstTBY, WstTBYBase {
    // =================== Constants ===================

    /// @notice Instance of the stTBY underlying token
    IERC20 private immutable _stTBYUnderlying;

    // ================== Constructor ==================

    constructor(address stTBY) WstTBYBase(stTBY) {
        _stTBYUnderlying = IStTBY(_stTBY).getUnderlyingToken();
    }

    // =================== Functions ===================

    /// @inheritdoc IWstTBY
    function depositUnderlying(
        uint256 amount
    ) external override returns (uint256 amountMinted) {
        _stageDeposit(address(_stTBYUnderlying), amount);

        amountMinted = _stTBY.depositUnderlying(amount);
        amountMinted = _mintWstTBY(amountMinted);
    }

    /// @inheritdoc IWstTBY
    function depositTby(
        address tby,
        uint256 amount
    ) external override returns (uint256 amountMinted) {
        _stageDeposit(tby, amount);

        amountMinted = _stTBY.depositTby(tby, amount);
        amountMinted = _mintWstTBY(amountMinted);
    }

    /// @inheritdoc IWstTBY
    function redeemWstTBY(
        uint256 amount
    ) external override returns (uint256 underlyingRedeemed) {
        _burn(msg.sender, amount);
        uint256 stTBYAmount = _stTBY.getUsdByShares(amount);

        underlyingRedeemed = _stTBY.redeemStTBY(stTBYAmount);

        _stTBYUnderlying.transfer(msg.sender, underlyingRedeemed);
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
}
