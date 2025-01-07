// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";
import {IStakeUpTokenLite} from "@StakeUp/interfaces/IStakeUpTokenLite.sol";

contract StakeUpTokenLite is IStakeUpTokenLite, ERC20, Ownable2Step {
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

    /// @inheritdoc IStakeUpTokenLite
    function mintFromPool(address to, uint256 amount) external onlyMintBurnRole {
        _mint(to, amount);
    }

    /// @inheritdoc IStakeUpTokenLite
    function burnFromPool(uint256 amount) external onlyMintBurnRole {
        _burn(msg.sender, amount);
    }

    function setMintBurnRole(address mintBurnRole) external onlyOwner {
        require(mintBurnRole != address(0), Errors.ZeroAddress());
        _mintBurnRole = mintBurnRole;
    }
}
