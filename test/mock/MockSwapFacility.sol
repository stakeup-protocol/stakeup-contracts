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

import {IMockSwapFacility} from "./interfaces/IMockSwapFacility.sol";

import {MockERC20} from "./MockERC20.sol";
import {ISwapRecipient} from "./interfaces/ISwapRecipient.sol";

contract MockSwapFacility is IMockSwapFacility {
    uint256 internal constant WAD = 1e18;

    error MockSwapFacility_WrongTokens(
        address inToken,
        address outToken,
        address token0,
        address token1
    );

    MockERC20 public immutable token0;
    MockERC20 public immutable token1;

    uint256 public exchangeRate;

    struct PendingSwap {
        address to;
        MockERC20 token;
        uint256 amount;
    }

    PendingSwap[] public pendingSwaps;

    constructor(MockERC20 token0_, MockERC20 token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setRate(uint256 newRate) external {
        exchangeRate = newRate;
    }

    function completeNextSwap() external {
        uint256 totalSwaps = pendingSwaps.length;
        require(totalSwaps > 0, "MockSwapFacility: No pending swaps");
        PendingSwap memory pswap = pendingSwaps[totalSwaps - 1];
        pendingSwaps.pop();
        pswap.token.mint(pswap.to, pswap.amount);
        ISwapRecipient(pswap.to).completeSwap(
            address(pswap.token),
            pswap.amount
        );
    }

    function swap(
        address inToken,
        address outToken,
        uint256 inAmount,
        bytes32[] calldata
    ) external {
        if (
            !((inToken == address(token0) && outToken == address(token1)) ||
                (inToken == address(token1) && outToken == address(token0)))
        ) {
            revert MockSwapFacility_WrongTokens(
                inToken,
                outToken,
                address(token0),
                address(token1)
            );
        }

        require(
            MockERC20(inToken).transferFrom(msg.sender, address(this), inAmount)
        );

        uint256 outAmount = inToken == address(token0)
            ? (inAmount * WAD) / exchangeRate
            : (inAmount * exchangeRate) / WAD;

        pendingSwaps.push(
            PendingSwap({
                to: msg.sender,
                token: MockERC20(outToken),
                amount: outAmount
            })
        );
    }
}
