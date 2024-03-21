// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

import {MockBloomPool, IERC20Metadata, IERC20} from "./MockBloomPool.sol";

interface IMockERC20 is IERC20 {
    function mint(address to, uint value) external;
    function burn(address from, uint value) external;
}

contract MockBloomPoolA is MockBloomPool {
   constructor(
      address _underlyingToken,
      address _billToken,
      address _swap
   ) MockBloomPool(_underlyingToken, _billToken, _swap, 6) {}

   function decimals() public view override returns (uint8) { 
      return 6;
   }

    function withdrawLender(uint256 _amount) override external {
        _burn(msg.sender, _amount);
        uint256 exchangeRate = swap.exchangeRate();
        uint256 amountToSend = (_amount * exchangeRate) /
            10 ** IERC20Metadata(billToken).decimals();
        uint256 underlyingBalance = IMockERC20(underlyingToken).balanceOf(address(this));
        if (amountToSend > underlyingBalance) {
            IMockERC20(underlyingToken).mint(
                address(this),
                amountToSend - underlyingBalance
            );
        }
        IMockERC20(underlyingToken).transfer(msg.sender, amountToSend);
    }

    function depositLender(
        uint256 amount
    ) external override returns (uint256 newId) { 
        IMockERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);
        return 0;
    }
}