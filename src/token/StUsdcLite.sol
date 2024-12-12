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
    /// @dev Total amount of USD excluding any yield that is accruing during the current day
    uint256 internal _totalUsdFloor;

    /// @dev Last rate update timestamp
    uint256 internal _lastRateUpdate;

    /// @dev The usdPerShare value at the time of the last rate update.
    uint256 internal _lastUsdPerShare;

    /// @dev The rewardPerSecond of yield accrual that is distributed 24 hours after rate updates (per share)
    uint256 internal _rewardPerSecond;

    /// @dev The address that has the mint and burn roles, will be set to the StUsdcTokenPool contract
    address private _mintBurnRole;

    // =================== Immutables ===================
    /// @notice WstUsdc token
    IWstUsdcLite private immutable _wstUsdc;

    // =================== Modifiers ===================

    modifier onlyMintBurnRole() {
        require(msg.sender == _mintBurnRole, Errors.UnauthorizedCaller());
        _;
    }

    // ================== Constructor ==================
    constructor(address layerZeroEndpoint, address bridgeOperator) RebasingERC20("staked USDC", "stUSDC") {
        _lastRateUpdate = block.timestamp;
        _lastUsdPerShare = FpMath.WAD;

        // Deploy the StakeUpKeeper contract
        _keeper = new StakeUpKeeper(address(this), layerZeroEndpoint, bridgeOperator);
    }

    // =================== Functions ==================
    /// @inheritdoc IStUsdcLite
    function setUsdPerShare(uint256 usdPerShare, uint256 timestamp) external onlyKeeper {
        _setUsdPerShare(usdPerShare, timestamp);
    }

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
        _setTotalUsdFloor(_totalUsdFloor + usdToCredit);
    }

    function burnShares(uint256 sharesAmount) external onlyMintBurnRole {
        uint256 usdToDebit = _amountByShares(sharesAmount);
        _burnShares(msg.sender, sharesAmount);
        _setTotalUsdFloor(_totalUsdFloor - usdToDebit);
    }

    function setMintBurnRole(address mintBurnRole) external onlyOwner {
        require(mintBurnRole != address(0), Errors.ZeroAddress());
        _mintBurnRole = mintBurnRole;
    }

    // =================== Internal Functions ===================

    /**
     * @dev This is used for calculating tokens from shares and vice versa.
     * @dev This function is required to be implemented in a derived contract.
     * @return Total amount of USD controlled by the protocol
     */
    function _totalUsd() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _lastRateUpdate;
        uint256 yieldPerShare = timeElapsed >= Constants.ONE_DAY
            ? (_rewardPerSecond.mulWad(Constants.ONE_DAY))
            : (_rewardPerSecond.mulWad(timeElapsed));
        uint256 yield = yieldPerShare.mulWad(_totalShares);
        return _totalUsdFloor + yield;
    }

    /**
     * @dev Set the floor amount of total USD excluding yield accruing from rewardPerSecond.
     * @param amount Amount
     */
    function _setTotalUsdFloor(uint256 amount) internal virtual {
        _totalUsdFloor = amount;
    }

    /// @dev This is called on the base chain before distributing yield to other chains
    function _setUsdPerShare(uint256 usdPerShare, uint256 timestamp) internal {
        // solidify the yield from the last 24 hours (stored as floor which will be used to update totalUsdFloor)
        uint256 floor = _totalUsd();
        _lastRateUpdate = timestamp;

        uint256 lastUsdPerShare_ = _lastUsdPerShare;
        if (usdPerShare > lastUsdPerShare_) {
            uint256 yieldPerShare = usdPerShare - lastUsdPerShare_;
            _rewardPerSecond = yieldPerShare.divWad(Constants.ONE_DAY);
        } else if (usdPerShare < lastUsdPerShare_) {
            _rewardPerSecond = 0;
            floor = usdPerShare.mulWad(_totalShares);
        }

        _setTotalUsdFloor(floor);
        _lastUsdPerShare = usdPerShare;
        emit UpdatedUsdPerShare(usdPerShare);
    }

    /// @inheritdoc RebasingERC20
    function _totalSupply() internal view virtual override returns (uint256) {
        return _totalUsd();
    }

    // =================== View Functions ===================

    /// @inheritdoc IStUsdcLite
    function totalUsdFloor() external view returns (uint256) {
        return _totalUsdFloor;
    }

    /// @inheritdoc IStUsdcLite
    function lastUsdPerShare() external view returns (uint256) {
        return _lastUsdPerShare;
    }

    /// @inheritdoc IStUsdcLite
    function rewardPerSecond() external view returns (uint256) {
        return _rewardPerSecond;
    }

    // /// @inheritdoc IStUsdcLite
    function lastRateUpdate() public view returns (uint256) {
        return _lastRateUpdate;
    }

    /// @notice Get the total USD value of the protocol
    function totalUsd() external view override returns (uint256) {
        return _totalUsd();
    }

    /// @inheritdoc IStUsdcLite
    function wstUsdc() external view returns (IWstUsdcLite) {
        return _wstUsdc;
    }
}
