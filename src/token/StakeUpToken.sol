// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";

contract StakeUpToken is IStakeUpToken, OFT, Ownable2Step {
    // =================== Storage ===================

    /// @notice The global supply of the token
    uint256 private _globalSupply;

    /// @notice Mapping of authorized minters status'
    mapping(address => bool) private _authorizedMinters;

    // ================== Immutables ===================

    /// @notice Address of the StakeUp Staking contract
    address private immutable _stakeupStaking;

    // =================== Modifiers ===================

    modifier onlyAuthorized() {
        if (!_authorizedMinters[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    // ================= Constructor =================

    constructor(
        address stakeupStaking,
        address gaugeDistributor, // Optional parameter for the gauge distributor
        address owner,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) OFT("StakeUp Token", "SUP", layerZeroEndpoint, layerZeroDelegate) Ownable2Step() {
        _stakeupStaking = stakeupStaking;

        _authorizedMinters[_stakeupStaking] = true;
        _authorizedMinters[address(IStakeUpStaking(stakeupStaking).stUsdc())] = true;

        if (gaugeDistributor != address(0)) {
            _authorizedMinters[gaugeDistributor] = true;
        }

        _transferOwnership(owner);
    }

    /**
     * @notice Mints SUP tokens
     * @dev This function is callable by the owner only
     * @param to The address that will receive the tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Mints SUP tokens and starts vesting within the StakeUp Staking contract
     * @dev This function is callable by the owner only
     * @param to The address that will mint and stake SUP tokens.
     * @param amount The amount of tokens to mint
     */
    function mintAndStartVest(address to, uint256 amount) external onlyOwner {
        _mintAndStartVest(to, amount);
    }

    /// @inheritdoc IStakeUpToken
    function mintRewards(address recipient, uint256 amount) external override onlyAuthorized {
        _mint(recipient, amount);
    }

    /// @inheritdoc IStakeUpToken
    function globalSupply() public view returns (uint256) {
        return _globalSupply;
    }

    /**
     * @notice Mints SUP tokens and starts vesting within the StakeUp Staking contract
     * @dev This function is callable by the owner only
     * @param to The address that will mint and stake SUP tokens.
     * @param amount The amount of tokens to mint
     */
    function _mintAndStartVest(address to, uint256 amount) internal {
        require(to != address(0), Errors.InvalidRecipient());
        // require(amount > 0, Errors.ZeroAmount);
        address stakeupStaking = _stakeupStaking;
        // Set the vesting state for this recipient in the vesting contract
        IStakeUpStaking(stakeupStaking).vestTokens(to, amount);
        // Mint the tokens to the vesting contract
        _mint(stakeupStaking, amount);
    }

    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) {
        super.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        super._transferOwnership(newOwner);
    }

    function _mint(address account, uint256 amount) internal override(ERC20) {
        if (globalSupply() + amount > Constants.MAX_SUPPLY) {
            revert Errors.ExceedsMaxSupply();
        }
        _globalSupply += amount;
        super._mint(account, amount);
    }
}