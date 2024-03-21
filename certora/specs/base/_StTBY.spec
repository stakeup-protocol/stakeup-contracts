import "./ReentrancyGuard/ReentrancyGuard_StTBY.spec";
import "./ERC20/ERC20_StTBY.spec";
import "./ERC20/IERC20.spec";
import "./ILayerZeroEndpoint.spec";
import "./IBloom.spec";

//////////////////// USING ////////////////////////

using StTBYHarness as _StTBY;
using StableTokenMockERC20 as underlying;

/////////////////// METHODS ///////////////////////

methods {

    // StTBYHarness
    function _StTBY.getLatestPool() external returns (address) envfree;
    function _StTBY.within24HoursOfCommitPhaseEnd(address, IBloomPool.State) external returns (bool);
    function _StTBY.isEligibleForAdjustment(IBloomPool.State state) external returns (bool) envfree;
    function _StTBY.getLastDepositAmount() external returns (uint256) envfree;
    function _StTBY.getMintRewardsRemaining() external returns (uint256) envfree;
    function _StTBY._scalingFactor() external returns (uint256) envfree;
    function _StTBY.getLastRateUpdate() external returns (uint256) envfree;

    // StTBY
    function _StTBY.depositTby(address tby, uint256 amount) external;
    function _StTBY.depositUnderlying(uint256 amount) external;
    function _StTBY.redeemStTBY(uint256 stTBYAmount) external returns (uint256);
    function _StTBY.redeemWstTBY(uint256 wstTBYAmount) external returns (uint256);
    function _StTBY.getRemainingBalance() external returns (uint256) envfree;
    function _StTBY.withdraw(address account, uint256 shares) external;
    function _StTBY.redeemUnderlying(address tby) external;
    function _StTBY.poke() external;
    function _StTBY.setNftTrustedRemote(uint16 remoteChainId, bytes path) external;
    function _StTBY.getWstTBY() external returns (address) envfree;
    function _StTBY.getUnderlyingToken() external returns (address) envfree;
    function _StTBY.getBloomFactory() external returns (address) envfree;
    function _StTBY.getExchangeRateRegistry() external returns (address) envfree;
    function _StTBY.getStakeupStaking() external returns (address) envfree;
    function _StTBY.getRewardManager() external returns (address) envfree;
    function _StTBY.getRedemptionNFT() external returns (address) envfree;
    function _StTBY.getMintBps() external returns (uint256) envfree;
    function _StTBY.getRedeemBps() external returns (uint256) envfree;
    function _StTBY.getPerformanceBps() external returns (uint256) envfree;
    function _StTBY.isTbyRedeemed(address tby) external returns (bool) envfree;

    // StTBYBase
    function _StTBY.circulatingSupply() external returns (uint256) envfree;
    function _StTBY.getTotalUsd() external returns (uint256) envfree;
    function _StTBY.getTotalShares() external returns (uint256) envfree;
    function _StTBY.sharesOf(address account) external returns (uint256) envfree;
    function _StTBY.getSharesByUsd(uint256 usdAmount) external returns (uint256) envfree;
    function _StTBY.getUsdByShares(uint256 sharesAmount) external returns (uint256) envfree;
    function _StTBY.transferShares(address recipient, uint256 sharesAmount) external returns (uint256);
    function _StTBY.transferSharesFrom(address sender, address recipient, uint256 sharesAmount) external returns (uint256);

    function _.decimals() external envfree;
    function _.getExchangeRate(address) external => ALWAYS(1000000000000000000);
    
    // Math
    function _.min(uint256 x, uint256 y) internal => min(x, y) expect (uint256);
}

////////////////// FUNCTIONS //////////////////////

function requireScalingFactor(env e) {
    require(underlying == _StTBY.getUnderlyingToken());
    uint8 myUnderlyingDecimals = underlying.decimals(e);
    require(_StTBY._scalingFactor() == assert_uint256(10^(18 - myUnderlyingDecimals)));
}

function min(uint256 a, uint256 b) returns uint256 {
    return a < b ? a : b;
}

///////////////// DEFINITIONS /////////////////////

function init_StTBY(env e) {
    init_ERC20_StTBY();
    requireScalingFactor(e);
}

///////////////// PROPERTIES //////////////////////

