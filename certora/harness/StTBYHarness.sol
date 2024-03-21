// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {StTBY} from "../munged/StTBYMunged.sol";
import {IStTBY} from "../../src/interfaces/IStTBY.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";

contract StTBYHarness is StTBY { 
    
    constructor(
        address underlyingToken,
        address stakeupStaking,
        address bloomFactory,
        address registry,
        uint16 mintBps_, // Suggested default 0.5%
        uint16 redeemBps_, // Suggested default 0.5%
        uint16 performanceBps_, // Suggested default 10% of yield
        address layerZeroEndpoint,
        address wstTBY
    ) StTBY(
        underlyingToken, 
        stakeupStaking, 
        bloomFactory, 
        registry, 
        mintBps_, 
        redeemBps_, 
        performanceBps_, 
        layerZeroEndpoint, 
        wstTBY
        ) { }
        
    function getLatestPool() external view returns (IBloomPool) {
        return _getLatestPool();
    }
        
    function getMintRewardsRemaining() external view returns (uint256) {
        return _mintRewardsRemaining;
    }

    function within24HoursOfCommitPhaseEnd(
        address pool,
        IBloomPool.State currentState
    ) external view returns (bool) {
        return _within24HoursOfCommitPhaseEnd(IBloomPool(pool), currentState);
    }

    function isEligibleForAdjustment(IBloomPool.State state) external pure returns (bool) {
        return  _isEligibleForAdjustment(state);
    }

    function getLastDepositAmount() external view returns (uint256) {
        return  _lastDepositAmount;
    }

    function getLastRateUpdate() external view returns (uint256) {
        return  _lastRateUpdate;
    }

    function _depositExternal(address token, uint256 amount, bool isTby) external {   
         _deposit(token, amount, isTby);
    }

    function _processProceedsExternal(uint256 proceeds, uint256 yield) external {   
         _processProceeds(proceeds, yield);
    }

    function _getCurrentTbyValueExternal() external view returns (uint256) {
        return _getCurrentTbyValue();
    }
}
