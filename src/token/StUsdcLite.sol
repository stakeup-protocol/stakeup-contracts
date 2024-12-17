// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpConstants as Constants} from "@StakeUp/helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {RebasingERC20} from "@StakeUp/token/RebasingERC20.sol";
import {IStUsdcLite} from "@StakeUp/interfaces/IStUsdcLite.sol";
import {IWstUsdcLite} from "@StakeUp/interfaces/IWstUsdcLite.sol";

/// @title Staked TBY Base Contract
contract StUsdcLite is IStUsdcLite, RebasingERC20 {
    using FpMath for uint256;

    // =================== Storage ===================
    /// @dev Total amount of Usd
    uint256 internal _totalUsd;

    /// @dev Last rate update timestamp
    uint256 internal _lastRateUpdate;

    /// @dev The address that has the mint and burn roles, will be set to the StUsdcTokenPool contract
    address private _mintBurnRole;

    // =================== Modifiers ===================

    modifier onlyMintBurnRole() {
        require(msg.sender == _mintBurnRole, Errors.UnauthorizedCaller());
        _;
    }

    // ================== Constructor ==================
    constructor(address owner) RebasingERC20("staked USDC", "stUSDC", owner) {
        require(owner != address(0), Errors.ZeroAddress());
        _lastRateUpdate = block.timestamp;
    }

    // =================== Functions ==================

    /// @notice Get the number of shares that are equivalent to a specified amount of USD
    function sharesByUsd(uint256 usdAmount) public view override returns (uint256) {
        return _sharesByAmount(usdAmount);
    }

    /// @notice Get the amount of USD that is equivalent to a specified amount of shares
    function usdByShares(uint256 sharesAmount) public view override returns (uint256) {
        return _amountByShares(sharesAmount);
    }

    // ==================== Chainlink Support ====================

    function mintShares(address to, uint256 sharesAmount) external onlyMintBurnRole {
        uint256 usdToCredit = _amountByShares(sharesAmount);
        _mintShares(to, sharesAmount);
        _setTotalUsd(_totalUsd + usdToCredit);
    }

    function burnShares(uint256 sharesAmount) external onlyMintBurnRole {
        uint256 usdToDebit = _amountByShares(sharesAmount);
        _burnShares(msg.sender, sharesAmount);
        _setTotalUsd(_totalUsd - usdToDebit);
    }

    function setMintBurnRole(address mintBurnRole) external onlyOwner {
        require(mintBurnRole != address(0), Errors.ZeroAddress());
        _mintBurnRole = mintBurnRole;
    }

    // =================== Internal Functions ===================
    /**
     * @dev Set the total amount of Usd.
     * @param amount Amount
     */
    function _setTotalUsd(uint256 amount) internal virtual {
        _totalUsd = amount;
    }

    /// @inheritdoc RebasingERC20
    function _totalSupply() internal view virtual override returns (uint256) {
        return _totalUsd;
    }

    // =================== View Functions ===================

    // /// @inheritdoc IStUsdcLite
    function lastRateUpdate() public view returns (uint256) {
        return _lastRateUpdate;
    }

    /// @notice Get the total USD value of the protocol
    function totalUsd() external view override returns (uint256) {
        return _totalUsd;
    }
}
