// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.23;

contract MockBPSFeed {
    // =================== Storage ===================

    uint256 public currentRate;
    uint256 public lastTimestamp;
    uint256 internal _totalRate;
    uint256 internal _totalDuration;

    // ================== Constants ==================
    uint256 internal constant INITIAL_RATE = 1e4;
    uint256 internal constant MAX_RATE = 1.5e4;

    constructor() {
        currentRate = INITIAL_RATE;
    }

    function getWeightedRate() external view returns (uint256) {
        return currentRate;
    }

    function updateRate(uint256 _rate) external {
        if (_rate < INITIAL_RATE || _rate > MAX_RATE) {
            revert("MockBPSFeed: rate out of bounds");
        }
        if (lastTimestamp > 0) {
            uint256 lastRateDuration = block.timestamp - lastTimestamp;
            _totalRate += currentRate * lastRateDuration;
            _totalDuration += lastRateDuration;
        }

        currentRate = _rate;
        lastTimestamp = block.timestamp;
    }
}
