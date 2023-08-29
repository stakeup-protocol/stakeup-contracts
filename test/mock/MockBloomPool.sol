// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.19;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMockSwapFacility} from "./interfaces/IMockSwapFacility.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockBloomPool is MockERC20 {
    using SafeTransferLib for address;

    address public immutable underlyingToken;
    address public immutable billToken;

    IMockSwapFacility public immutable swap;

    constructor(
        address _underlyingToken,
        address _billToken,
        address _swap,
        uint8 _decimals
    ) MockERC20(_decimals) {
        underlyingToken = _underlyingToken;
        billToken = _billToken;
        swap = IMockSwapFacility(_swap);
    }

    function initiatePreHoldSwap() external {
        uint256 amountToSwap = underlyingToken.balanceOf(address(this));
        underlyingToken.safeApprove(address(swap), amountToSwap);
        swap.swap(underlyingToken, billToken, amountToSwap, new bytes32[](0));
    }

    function initiatePostHoldSwap() external {
        uint256 amountToSwap = billToken.balanceOf(address(this));
        billToken.safeApprove(address(swap), amountToSwap);
        swap.swap(billToken, underlyingToken, amountToSwap, new bytes32[](0));
    }

    function completeSwap(address outToken, uint256 outAmount) external {}

    function withdrawLender(uint256 _amount) external {
        _burn(msg.sender, _amount);
        uint256 exchangeRate = swap.exchangeRate();
        uint256 amountToSend = _amount * exchangeRate / 1e18 * (10 ** IERC20Metadata(underlyingToken).decimals()) / (10 ** IERC20Metadata(billToken).decimals());
        underlyingToken.safeTransfer(msg.sender, amountToSend);
    }
}
