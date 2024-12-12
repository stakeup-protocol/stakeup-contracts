// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

contract StakeUpTokenLite is ERC20Burnable, Ownable2Step {
    // =================== Storage ===================
    address private _mintBurnRole;

    // =================== Constructor ===================
    constructor() ERC20("StakeUpToken", "SUP") Ownable2Step() {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== Modifiers ===================
    modifier onlyMintBurnRole() {
        require(msg.sender == _mintBurnRole, Errors.UnauthorizedCaller());
        _;
    }

    // ==================== Chainlink Support ====================

    /// @notice Mint tokens from the pool.
    function mintFromPool(address to, uint256 amount) external onlyMintBurnRole {
        _mint(to, amount);
    }

    /// @notice Burn tokens from the pool.
    function burnFromPool(uint256 amount) external onlyMintBurnRole {
        _burn(msg.sender, amount);
    }

    function setMintBurnRole(address mintBurnRole) external onlyOwner {
        require(mintBurnRole != address(0), Errors.ZeroAddress());
        _mintBurnRole = mintBurnRole;
    }
}
