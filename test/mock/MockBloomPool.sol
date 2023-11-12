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
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMockSwapFacility} from "./interfaces/IMockSwapFacility.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";

import {MockERC20} from "./MockERC20.sol";

contract MockBloomPool is IBloomPool, MockERC20 {
    using SafeTransferLib for address;

    address public immutable underlyingToken;
    address public immutable billToken;

    IMockSwapFacility public immutable swap;

    State private _state;
    uint256 private _commitPhaseEnd;

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
        uint256 amountToSend = _amount * exchangeRate / 10 ** IERC20Metadata(billToken).decimals();
        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));
        if (amountToSend > underlyingBalance) {
            MockERC20(underlyingToken).mint(address(this), amountToSend - underlyingBalance);
        }
        underlyingToken.safeTransfer(msg.sender, amountToSend);
    }

    function depositLender(
        uint256 amount
    ) external override returns (uint256 newId) {
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        return 0;
    }

    function state() external view override returns (State currentState) {
        return _state;
    }

    function COMMIT_PHASE_END() external view override returns (uint256) {
        return _commitPhaseEnd;
    }

    function setCommitPhaseEnd(uint256 _newCommitPhaseEnd) external {
        _commitPhaseEnd = _newCommitPhaseEnd;
    }

    function setState(State _newState) external {
        _state = _newState;
    }
}
