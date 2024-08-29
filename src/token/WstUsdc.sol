// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {StUsdcLite} from "./StUsdcLite.sol";
import {WstUsdcLite} from "./WstUsdcLite.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IWstUsdc} from "../interfaces/IWstUsdc.sol";

/**
 * @title Wrapped Staked TBY
 * @notice The non-rebasing, wrapped version of the stTBY token that accues yield from TBYs
 */
contract WstUsdc is IWstUsdc, WstUsdcLite {
    // =================== Constants ===================

    /// @notice Instance of the stTBY underlying token
    IERC20 private immutable _stUsdcAsset;

    // ================== Constructor ==================

    constructor(address stTBY) WstUsdcLite(stTBY) {
        _stUsdcAsset = IStUsdc(_stTBY).asset();
    }

    // =================== Functions ===================

    /// @inheritdoc IWstUsdc
    function depositAsset(uint256 amount) external override returns (uint256 amountMinted) {
        _stageDeposit(address(_stUsdcAsset), amount);

        amountMinted = _stUsdc.depositAsset(amount);
        amountMinted = _mintWstUsdc(amountMinted);
    }

    /// @inheritdoc IWstUsdc
    function depositTby(address tby, uint256 amount) external override returns (uint256 amountMinted) {
        _stageDeposit(tby, amount);

        amountMinted = _stTBY.depositTby(tby, amount);
        amountMinted = _mintWstUsdc(amountMinted);
    }

    /// @inheritdoc IWstUsdc
    function redeemWstUsdc(uint256 amount) external override returns (uint256 underlyingRedeemed) {
        _burn(msg.sender, amount);
        uint256 stTBYAmount = _stTBY.getUsdByShares(amount);

        underlyingRedeemed = _stTBY.redeemStUsdc(stTBYAmount);

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
