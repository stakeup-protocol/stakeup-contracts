// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";
import {AggregatorV3Interface} from "@chainlink-shared/interfaces/AggregatorV3Interface.sol";

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

    /// @dev The address that has the mint and burn roles, will be set to the StUsdcTokenPool contract
    address private _mintBurnRole;

    /// @dev The address of the data feed that returns the USD per share (Only used for Lite Deployments)
    address private _usdPerShareFeed;

    // =================== Immutables ===================
    /// @dev Whether the token is a Lite Deployment
    bool private immutable _isLite;

    // =================== Modifiers ===================
    modifier onlyMintBurnRole() {
        require(msg.sender == _mintBurnRole, Errors.UnauthorizedCaller());
        _;
    }

    // ================== Constructor ==================
    constructor(bool isLite_, address owner) RebasingERC20("staked USDC", "stUSDC", owner) {
        require(owner != address(0), Errors.ZeroAddress());
        _isLite = isLite_;
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

    /// @inheritdoc IStUsdcLite
    function mintShares(address to, uint256 sharesAmount) external onlyMintBurnRole {
        uint256 usdToCredit = _amountByShares(sharesAmount);
        _mintShares(to, sharesAmount);
        _setTotalUsd(_totalUsd + usdToCredit);
    }

    /// @inheritdoc IStUsdcLite
    function burnShares(uint256 sharesAmount) external onlyMintBurnRole {
        uint256 usdToDebit = _amountByShares(sharesAmount);
        _burnShares(msg.sender, sharesAmount);
        _setTotalUsd(_totalUsd - usdToDebit);
    }

    /**
     * @notice Set the address of the contract that has the mint and burn roles
     * @dev The mint and burn roles will be set to the StUsdcTokenPool contract
     * @param address_ Address of the contract that has the mint and burn roles
     */
    function setMintBurnRole(address address_) external onlyOwner {
        require(address_ != address(0), Errors.ZeroAddress());
        _mintBurnRole = address_;
    }

    /// @notice Set the address of the data feed that returns the USD per share
    function setUsdPerShareFeed(address feed) external onlyOwner {
        require(feed != address(0), Errors.ZeroAddress());
        _usdPerShareFeed = feed;
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
        // If this is a Lite deployment, we must rely on the data feed to calculate the total supply
        if (_isLite) {
            uint256 usdPerShare = _usdPerShareAnswer();
            return usdPerShare.mulWad(_totalShares);
        }
        // Otherwise, we can rely on the totalUsd variable
        return _totalUsd;
    }

    /// @notice Retrieves the latest USD per share value from the data feed.
    function _usdPerShareAnswer() internal view returns (uint256) {
        (, int256 answer,,,) = AggregatorV3Interface(_usdPerShareFeed).latestRoundData();
        if (answer <= 0) revert Errors.InvalidAnswer();

        uint256 usdPerShare = uint256(answer);
        return usdPerShare;
    }

    // =================== View Functions ===================
    /// @inheritdoc IStUsdcLite
    function totalUsd() external view override returns (uint256) {
        return _totalSupply();
    }

    /// @inheritdoc IStUsdcLite
    function usdPerShareAnswer() external view override returns (uint256) {
        require(_isLite, Errors.InvalidOperation());
        return _usdPerShareAnswer();
    }

    /// @inheritdoc IStUsdcLite
    function mintBurnRole() external view override returns (address) {
        return _mintBurnRole;
    }

    /// @inheritdoc IStUsdcLite
    function usdPerShareFeed() external view override returns (address) {
        return _usdPerShareFeed;
    }

    /// @inheritdoc IStUsdcLite
    function isLite() external view override returns (bool) {
        return _isLite;
    }
}
