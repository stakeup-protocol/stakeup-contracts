import "./ERC20/ERC20_WstTBY.spec";
import "./ERC20/IERC20.spec";

//////////////////// USING ////////////////////////

using WstTBYHarness as _WstTBY;

/////////////////// METHODS ///////////////////////

methods {

    // WstTBY
    function _WstTBY.wrap(uint256 stTBYAmount) external returns (uint256);
    function _WstTBY.unwrap(uint256 wstTBYAmount) external returns (uint256);
    function _WstTBY.getWstTBYByStTBY(uint256 stTBYAmount) external returns (uint256) envfree;
    function _WstTBY.getStTBYByWstTBY(uint256 wstTBYAmount) external returns (uint256) envfree;
    function _WstTBY.stTBYPerToken() external returns (uint256) envfree;
    function _WstTBY.tokensPerStTBY() external returns (uint256) envfree;
    function _WstTBY.getStTBY() external returns (address) envfree;
}