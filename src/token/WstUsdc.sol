// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {StUsdcLite} from "./StUsdcLite.sol";
import {WstUsdcLite} from "./WstUsdcLite.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IWstUsdc} from "../interfaces/IWstUsdc.sol";

/**
 * @title Wrapped Staked TBY
 * @notice The non-rebasing, wrapped version of the stUsdc token that accues yield from TBYs
 */
contract WstUsdc is IWstUsdc, WstUsdcLite, ERC1155TokenReceiver {
    using SafeERC20 for IERC20;
    // =================== Immutables ===================
    /// @notice Instance of the stUsdc underlying token

    IERC20 private immutable _stUsdcAsset;

    /// @notice Instance of the TBY token
    ERC1155 private immutable _tby;

    /// @notice Instance of the SUP token
    IERC20 private immutable _sup;

    // ================== Constructor ==================
    constructor(address stUsdc_) WstUsdcLite(stUsdc_) {
        _stUsdcAsset = IStUsdc(stUsdc_).asset();
        _tby = IStUsdc(stUsdc_).tby();
        _sup = IERC20(address(IStUsdc(stUsdc_).stakeUpToken()));
        // Set approval for stUsdc to be able to transfer TBYs on behalf of the WstUsdc contract
        _tby.setApprovalForAll(address(stUsdc_), true);
    }

    // =================== Functions ===================

    /// @inheritdoc IWstUsdc
    function depositAsset(uint256 amount) external override returns (uint256 amountMinted) {
        _stUsdcAsset.safeTransferFrom(msg.sender, address(this), amount);
        _stUsdcAsset.safeApprove(address(_stUsdc), amount);
        amountMinted = _stUsdc.depositAsset(amount);
        amountMinted = _mintWstUsdc(amountMinted);
    }

    /// @inheritdoc IWstUsdc
    function depositTby(uint256 tbyId, uint256 amount) external override returns (uint256 amountMinted) {
        _tby.safeTransferFrom(msg.sender, address(this), tbyId, amount, "");
        amountMinted = _stUsdc.depositTby(tbyId, amount);

        uint256 supStartBalance = _sup.balanceOf(address(this));
        amountMinted = _mintWstUsdc(amountMinted);

        // If SUP rewards have been minted, transfer to the user
        uint256 supEndBalance = _sup.balanceOf(address(this));
        if (supEndBalance > supStartBalance) {
            uint256 supMinted = supEndBalance - supStartBalance;
            _sup.safeTransfer(msg.sender, supMinted);
        }
    }

    /// @inheritdoc IWstUsdc
    function redeemWstUsdc(uint256 amount) external override returns (uint256 assetsRedeemed) {
        _burn(msg.sender, amount);
        uint256 stUsdcAmount = _stUsdc.usdByShares(amount);
        assetsRedeemed = _stUsdc.redeemStUsdc(stUsdcAmount);
        _stUsdcAsset.safeTransfer(msg.sender, assetsRedeemed);
    }
}
