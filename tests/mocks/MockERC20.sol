// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 internal _decimals;

    constructor(uint8 d) ERC20("Mock Token", "MCK") {
        _decimals = d;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // This function is for testing stTBY
    function getUsdByShares(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    // This function is for testing the minting Rewards
    function mintRewards(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// Used for unit testing the staking rewards
    function sharesOf(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /// Used for unit testing the staking rewards
    function transferShares(
        address to,
        uint256 amount
    ) external returns (uint256) {
        transfer(to, amount);
        return amount;
    }
}
