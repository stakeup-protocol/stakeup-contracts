// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {StakeUpConstants as Constants} from "@StakeUp/helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {StakeUpTokenLite} from "@StakeUp/token/StakeUpTokenLite.sol";

import {IStakeUpToken} from "@StakeUp/interfaces/IStakeUpToken.sol";
import {IStakeUpStaking} from "@StakeUp/interfaces/IStakeUpStaking.sol";

contract StakeUpToken is IStakeUpToken, StakeUpTokenLite, Ownable2Step {
    // =================== Storage ===================
    /// @notice The global supply of the token
    uint256 private _globalSupply;

    /// @notice Mapping of authorized minters status'
    mapping(address => bool) private _authorizedMinters;

    /// @notice Address of the StakeUp Staking contract
    address private _stakeupStaking;

    /// @notice If the contract is initialized
    bool internal _initialized;

    // =================== Modifiers ===================
    modifier initialized() {
        require(_initialized, Errors.NotInitialized());
        _;
    }

    modifier onlyAuthorized() {
        require(_authorizedMinters[msg.sender], Errors.UnauthorizedCaller());
        _;
    }

    // ================= Constructor =================
    constructor(address owner, address layerZeroEndpoint, address bridgeOperator)
        StakeUpTokenLite(layerZeroEndpoint, bridgeOperator)
        Ownable2Step()
    {
        require(owner != address(0), Errors.ZeroAddress());
        _transferOwnership(owner);
    }

    // =================== Functions ===================
    function initialize(address stakeupStaking, address gaugeDistributor) external onlyOwner {
        require(!_initialized, Errors.AlreadyInitialized());
        _initialized = true;
        _stakeupStaking = stakeupStaking;

        _authorizedMinters[_stakeupStaking] = true;
        _authorizedMinters[address(IStakeUpStaking(stakeupStaking).stUsdc())] = true;

        if (gaugeDistributor != address(0)) {
            _authorizedMinters[gaugeDistributor] = true;
        }
    }

    /**
     * @notice Mints SUP tokens
     * @dev This function is callable by the owner only
     * @param to The address that will receive the tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public initialized onlyOwner {
        _updateGlobalSupply(amount);
        _mint(to, amount);
    }

    /**
     * @notice Mints SUP tokens and starts vesting within the StakeUp Staking contract
     * @dev This function is callable by the owner only
     * @param to The address that will mint and stake SUP tokens.
     * @param amount The amount of tokens to mint
     */
    function mintAndStartVest(address to, uint256 amount) external initialized onlyOwner {
        _mintAndStartVest(to, amount);
    }

    /// @inheritdoc IStakeUpToken
    function mintRewards(address recipient, uint256 amount) external override initialized onlyAuthorized {
        _updateGlobalSupply(amount);
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
        require(amount > 0, Errors.ZeroAmount());

        _updateGlobalSupply(amount);
        // Set the vesting state for this recipient in the vesting contract & mint tokens
        address stakeupStaking = _stakeupStaking;
        IStakeUpStaking(stakeupStaking).vestTokens(to, amount);
        _mint(stakeupStaking, amount);
    }

    /**
     * @notice Updates the global supply of the token
     * @dev Makes sure the the total supply of all tokens on all chains does not exceed the maximum supply
     * @param amount The amount of tokens to increment the global supply by
     */
    function _updateGlobalSupply(uint256 amount) internal {
        if (globalSupply() + amount > Constants.MAX_SUPPLY) {
            revert Errors.ExceedsMaxSupply();
        }
        _globalSupply += amount;
    }

    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) {
        super.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        super._transferOwnership(newOwner);
    }
}
