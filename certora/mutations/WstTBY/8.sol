// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IWstTBY} from "../interfaces/IWstTBY.sol";

contract WstTBY is IWstTBY, ERC20 {
    // =================== Constants ===================

    IStTBY private immutable _stTBY;

    // =================== Functions ===================

    constructor(address stTBY) ERC20("Wrapped staked TBY", "wstTBY") {
        _stTBY = IStTBY(stTBY);
    }

    /// @inheritdoc IWstTBY
    function wrap(uint256 stTBYAmount) external returns (uint256) {
        if (stTBYAmount == 0) revert ZeroAmount();
        uint256 wstTBYAmount = _stTBY.getSharesByUsd(stTBYAmount);
        _mint(msg.sender, wstTBYAmount);
        ERC20(address(_stTBY)).transferFrom(
            msg.sender,
            address(this),
            stTBYAmount
        );
        return wstTBYAmount;
    }

    /// @inheritdoc IWstTBY
    function unwrap(uint256 wstTBYAmount) external returns (uint256) {
        if (wstTBYAmount == 0) revert ZeroAmount();
        uint256 stTBYAmount = _stTBY.getUsdByShares(wstTBYAmount);
        _burn(msg.sender, wstTBYAmount);
        ERC20(address(_stTBY)).transfer(msg.sender, stTBYAmount);
        return stTBYAmount;
    }

    /// @inheritdoc IWstTBY
    function getWstTBYByStTBY(
        uint256 stTBYAmount
    ) external view returns (uint256) {
        return _stTBY.getSharesByUsd(stTBYAmount);
    }

    /// @inheritdoc IWstTBY
    function getStTBYByWstTBY(
        uint256 wstTBYAmount
    ) external view returns (uint256) {
        return _stTBY.getUsdByShares(wstTBYAmount);

/**************************** Diff Block Start ****************************
diff --git a/src/token/WstTBY.sol b/src/token/WstTBY.sol
index 7cb07f9..b704615 100644
--- a/src/token/WstTBY.sol
+++ b/src/token/WstTBY.sol
@@ -55,7 +55,7 @@ contract WstTBY is IWstTBY, ERC20 {
 
     /// @inheritdoc IWstTBY
     function stTBYPerToken() external view returns (uint256) {
-        return _stTBY.getUsdByShares(1 ether);
+        return _stTBY.getUsdByShares(0.1 ether);
     }
 
     /// @inheritdoc IWstTBY
**************************** Diff Block End *****************************/

    }

    /// @inheritdoc IWstTBY
    function stTBYPerToken() external view returns (uint256) {
        return _stTBY.getUsdByShares(0.1 ether);
    }

    /// @inheritdoc IWstTBY
    function tokensPerStTBY() external view returns (uint256) {
        return _stTBY.getSharesByUsd(1 ether);
    }

    /// @inheritdoc IWstTBY
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }
}
