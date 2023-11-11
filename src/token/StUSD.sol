// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RedemptionNFT} from "./RedemptionNFT.sol";
import {StUSDBase} from "./StUSDBase.sol";

import {IBloomFactory} from "../interfaces/bloom/IBloomFactory.sol";
import {IBloomPool} from "../interfaces/bloom/IBloomPool.sol";
import {IExchangeRateRegistry} from "../interfaces/bloom/IExchangeRateRegistry.sol";
import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IWstUSD} from "../interfaces/IWstUSD.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";

/// @title Staked USD Contract
contract StUSD is StUSDBase, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWstUSD;

    // =================== Storage ===================

    /// @notice WstUSD token
    IWstUSD public wstUSD;

    /// @dev Underlying token
    IERC20 public underlyingToken;

    IBloomFactory public bloomFactory;

    IExchangeRateRegistry public registry;

    IStakeupStaking public stakeupStaking;

    IRewardManager public rewardManager;

    RedemptionNFT public redemptionNFT;

    /// @dev Underlying token decimals
    uint8 internal _underlyingDecimals;

    /// @notice Mint fee bps
    uint16 public immutable mintBps;

    /// @notice Redeem fee bps
    uint16 public immutable redeemBps;

    /// @notice Performance fee bps
    uint16 public immutable performanceBps;

    uint16 public constant BPS = 10000;

    uint16 public constant MAX_BPS = 200; // Max 2%

    uint256 public constant AUTO_STAKE_PHASE = 1 days;

    /// @dev Last deposit amount
    uint256 internal _lastDepositAmount;

    /// @dev Remaining underlying token balance
    uint256 internal _remainingBalance;

    /// @dev Last rate update timestamp
    uint256 internal _lastRateUpdate;

    // =================== Modifiers ===================
    modifier onlyUnStUSD() {
        if (_msgSender() != address(redemptionNFT)) revert CallerNotUnStUSD();
        _;
    }

    // =================== Functions ===================
    constructor(
        address _underlyingToken,
        address _stakeupStaking,
        address _bloomFactory,
        address _registry,
        uint16 _mintBps, // Suggested default 0.5%
        uint16 _redeemBps, // Suggested default 0.5%
        uint16 _performanceBps, // Suggested default 10% of yield
        address _layerZeroEndpoint,
        address _wstUSD
    )
        StUSDBase(_layerZeroEndpoint)
    {
        if (_underlyingToken == address(0)) revert InvalidAddress();
        if (_wstUSD == address(0)) revert InvalidAddress();
        if (_bloomFactory == address(0)) revert InvalidAddress();
        if (_registry == address(0)) revert InvalidAddress();
        if (_stakeupStaking == address(0)) revert InvalidAddress();
        if (_mintBps > MAX_BPS || _redeemBps > MAX_BPS) revert ParameterOutOfBounds();
        
        underlyingToken = IERC20(_underlyingToken);
        _underlyingDecimals = IERC20Metadata(_underlyingToken).decimals();
        bloomFactory = IBloomFactory(_bloomFactory);
        registry = IExchangeRateRegistry(_registry);
        stakeupStaking = IStakeupStaking(_stakeupStaking);
        rewardManager = IRewardManager(stakeupStaking.getRewardManager());

        mintBps = _mintBps;
        redeemBps = _redeemBps;
        performanceBps = _performanceBps;

        wstUSD = IWstUSD(_wstUSD);

        redemptionNFT = new RedemptionNFT(
            "stUSD Redemption NFT",
            "unstUSD",
            address(this),
            _layerZeroEndpoint
        );
    }

    /**
     * @notice Get the total amount of underlying tokens in the pool
     */
    function getRemainingBalance() external view returns (uint256) {
        return _remainingBalance;
    }

    /**
     * @notice Deposit TBY and get stUSD minted
     * @param _tby TBY address
     * @param _amount TBY amount to deposit
     */
    function depositTby(address _tby, uint256 _amount) external {
        if (!registry.tokenInfos(_tby).active) revert TBYNotActive();
        IBloomPool latestPool = _getLatestPool();

        IERC20(_tby).safeTransferFrom(msg.sender, address(this), _amount);

        if (_tby == address(latestPool)) {
            _lastDepositAmount += _amount;
        }
        
        _deposit(_tby, _amount);
    }
    
    /**
     * @notice Deposit underlying tokens and get stUSD minted
     * @param _amount Amount of underlying tokens to deposit
     */
    function depostUnderlying(uint256 _amount) external {
        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        IBloomPool latestPool = _getLatestPool();

        if (latestPool.state() == IBloomPool.State.Commit) {
            _lastDepositAmount += _amount;
            underlyingToken.safeApprove(address(latestPool), _amount);
            latestPool.depositLender(_amount);
        } else {
            _remainingBalance += _amount;
        }
        
        _deposit(address(underlyingToken), _amount);
    }

    /**
     * @notice Redeem stUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param _stUSDAmount Amount of stUSD
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemStUSD(uint256 _stUSDAmount) external nonReentrant returns (uint256) {
        return _redeemStUSD(_stUSDAmount);
    }

    /**
     * @notice Redeem wstUSD in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param _wstUSDAmount Amount of wstUSD
     * @return uint256 The tokenId of the redemption NFT
     */
    function redeemWstUSD(uint256 _wstUSDAmount) external nonReentrant returns (uint256) {
        IERC20(address(wstUSD)).safeTransferFrom(msg.sender, address(this), _wstUSDAmount);
        uint256 _stUSDAmount = wstUSD.unwrap(_wstUSDAmount);
        _transfer(address(this), msg.sender, _stUSDAmount);
        return _redeemStUSD(_stUSDAmount);
    }

    function _redeemStUSD(uint256 _stUSDAmount) internal returns (uint256) {
        if (_stUSDAmount == 0) revert ParameterOutOfBounds();

        uint256 shares = getSharesByUsd(_stUSDAmount);
        
        (uint256 redemptonId, uint256 amountRedeemed) = _redeem(msg.sender, shares, _stUSDAmount);

        emit Redeemed(msg.sender, shares, amountRedeemed);

        return redemptonId;
    }

    /**
     * @notice Withdraw redeemed underlying tokens
     * @dev Emits a {Withdrawn} event.
     * @dev Entrypoint for the withdrawl process is the RedemptionNFT contract
     */
    function withdraw(address account, uint256 shares) external override nonReentrant onlyUnStUSD {
        uint256 amount = getUsdByShares(shares);

        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));

        if (amount != 0) {
            uint256 transferAmount = amount / (10 ** (18 - _underlyingDecimals));

            if (transferAmount > underlyingBalance) revert InsufficientBalance();

            underlyingToken.safeTransfer(account, transferAmount);
    
            _burnShares(address(redemptionNFT), shares);
            _setTotalUsd(_getTotalUsd() - amount);

        }

        emit Withdrawn(msg.sender, amount);
    }

    function _redeem(address _account, uint256 _shares, uint256 _underlyingAmount)
        internal returns (uint256 redemptionId, uint256 amountRedeemed)
    {
        if (balanceOf(_account) < _underlyingAmount) revert InsufficientBalance();

        uint256 redeemFee = (_shares * redeemBps) / BPS;

        if (redeemFee > 0) {
            _shares -= redeemFee;
            uint256 redeemFeeAmount = getUsdByShares(redeemFee);
            _underlyingAmount -= redeemFeeAmount;

            _transferShares(_account, address(stakeupStaking), redeemFee);
            
            stakeupStaking.processFees(redeemFee);

            emit FeeCaptured(FeeType.Redeem, redeemFee);
        }

        _transferShares(_account, address(redemptionNFT), _shares);

        redemptionId = _mintRedemptionNFT(_account, _shares);

        return (redemptionId, _underlyingAmount);
    }

    /**
     * @dev Process new proceeds by applying them to redemptions and undeployed
     * cash
     * @param _proceeds Proceeds in underlying tokens
     * @param _yield Yield gained from TBY
     */
    function _processProceeds(uint256 _proceeds, uint256 _yield) internal {
        uint256 scalingFactor = 10 ** (18 - _underlyingDecimals);
        uint256 underlyingGains = _yield * scalingFactor;

        uint256 performanceFee = underlyingGains * performanceBps / BPS;

        if (performanceFee > 0) {
            uint256 sharesFeeAmount = getSharesByUsd(performanceFee);

            _mintShares(address(stakeupStaking), sharesFeeAmount);
            
            stakeupStaking.processFees(sharesFeeAmount);

            emit FeeCaptured(FeeType.Performance, sharesFeeAmount);
        }

        if (_proceeds > 0) {
            _remainingBalance += _proceeds;
        }
        
        _setTotalUsd(_getCurrentTbyValue() + underlyingGains);
    }

    /**
     * @notice Redeem underlying token from TBY
     * @param _tby TBY address
     * @param _amount Redeem amount
     */
    function redeemUnderlying(address _tby, uint256 _amount) external {
        IBloomPool pool = IBloomPool(_tby);

        _amount = Math.min(_amount, IERC20(_tby).balanceOf(address(this)));

        uint256 beforeUnderlyingBalance = underlyingToken.balanceOf(address(this));

        pool.withdrawLender(_amount);

        uint256 withdrawn = underlyingToken.balanceOf(address(this)) - beforeUnderlyingBalance;
        
        uint256 yieldFromPool = withdrawn - _amount;

        _processProceeds(withdrawn, yieldFromPool);

        if (_amount > 0) {
            rewardManager.distributePokeRewards(msg.sender);
        }
    }

    /**
     * @notice Invokes the auto stake feature or adjusts the remaining balance
     * if the most recent deposit did not get fully staked
     * @dev autoMint feature is invoked if the last created pool is in
     * the commit state
     * @dev remainingBalance adjustment is invoked if the last created pool is
     * in any other state than commit and deposits dont get fully staked
     * @dev anyone can call this function for now
     */
    function poke() external {
        IBloomPool lastCreatedPool = _getLatestPool();
        IBloomPool.State currentState = lastCreatedPool.state();
        bool eligableForReward = false;

        // If we haven't updated the values of TBYs in 24 hours, update it now
        if (block.timestamp - _lastRateUpdate > 1 days) {
            _lastRateUpdate = block.timestamp;
            
            uint256 currentUsdTotal = _getTotalUsd();
            uint256 valueAccrual = currentUsdTotal - _getCurrentTbyValue();

            _setTotalUsd(currentUsdTotal + valueAccrual);
        }

        if (_within24HoursOfCommitPhaseEnd(lastCreatedPool, currentState)) {
            if (_autoMintTBY(lastCreatedPool) > 0) {
                eligableForReward = true;
            }
        }

        if (_isElegibleForAdjustment(currentState)) {
            if (_adjustRemainingBalance(lastCreatedPool) > 0) {
                eligableForReward = true;
            }
        }

        if (eligableForReward) {
            rewardManager.distributePokeRewards(msg.sender);
        }
    }

    function _deposit(address token, uint256 amount) internal {   
        // TBYs will always have the same underlying decimals as the underlying token
        uint256 amountScaled = amount * 10 ** (18 - _underlyingDecimals);

        uint256 sharesFeeAmount;
        uint256 mintFee = (amountScaled * mintBps) / BPS;

        if (mintFee > 0) {
            sharesFeeAmount = getSharesByUsd(mintFee);

            stakeupStaking.processFees(sharesFeeAmount);

            emit FeeCaptured(FeeType.Mint, sharesFeeAmount);
        }

        uint256 sharesAmount = getSharesByUsd(amountScaled - mintFee);

        _mintShares(msg.sender, sharesAmount);
        _mintShares(address(stakeupStaking), sharesFeeAmount);

        _setTotalUsd(_getTotalUsd() + amountScaled);

        emit Deposit(msg.sender, token, amount, sharesAmount);
    }

    /**
     * @notice Auto stake USDC in the latest Bloom pool
     * @dev Auto stake feature can only be executed during the last 24 hours of
     * the newest Bloom Pool's commit phase
     * @param pool The latest Bloom pool
     * @return uint256 Amount of USDC auto staked into the pool
     */
    function _autoMintTBY(IBloomPool pool) internal returns (uint256) {
        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));

        if (underlyingBalance > 0) {
            uint256 accountedBalance = _remainingBalance;
            uint256 unregisteredBalance = underlyingBalance - accountedBalance;
            
            delete _remainingBalance;

            underlyingToken.safeApprove(address(pool), underlyingBalance);
            pool.depositLender(underlyingBalance);

            uint256 scaledUnregisteredBalance = unregisteredBalance * 10 ** (18 - _underlyingDecimals);

            _setTotalUsd(_getTotalUsd() + scaledUnregisteredBalance);

            emit TBYAutoMinted(address(pool), underlyingBalance);
        }

        return underlyingBalance;
    }

    function _within24HoursOfCommitPhaseEnd(IBloomPool pool, IBloomPool.State currentState) internal view returns (bool) {
        uint256 commitPhaseEnd = pool.COMMIT_PHASE_END();
        uint256 last24hoursOfCommitPhase = pool.COMMIT_PHASE_END() - AUTO_STAKE_PHASE;

        if (currentState == IBloomPool.State.Commit) {
            uint256 currentTime = block.timestamp;
            if (currentTime >= last24hoursOfCommitPhase && currentTime < commitPhaseEnd) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Check if the pool is elegible for adjustment
     * @param _state Pool state
     * @return bool True if the pool is in a state that allows for adjustment
     */
    function _isElegibleForAdjustment(IBloomPool.State _state) internal pure returns (bool) {
        return _state != IBloomPool.State.Commit
            && _state != IBloomPool.State.FinalWithdraw
            && _state != IBloomPool.State.EmergencyExit;
    }

    /**
     * @notice Adjust the remaining balance to account for the difference between
     * the last deposit amount and the current balance of the latest TBYs
     * @param pool The latest Bloom pool
     * @return uint256 The difference between deposit amount and current balance
     */
    function _adjustRemainingBalance(IBloomPool pool) internal returns (uint256) {
        uint256 depositDifference;
        uint256 latestTbyBalance = IERC20(address(pool)).balanceOf(address(this));

        if (_lastDepositAmount > latestTbyBalance) {
            depositDifference = _lastDepositAmount - latestTbyBalance;
            _remainingBalance += depositDifference;
            emit RemainingBalanceAdjusted(_remainingBalance);
        }
        _lastDepositAmount = 0;

        return depositDifference;
    }

    /**
     * @notice Gets the latest pool created by the BloomFactory
     * @return IBloomPool The latest pool
     */
    function _getLatestPool() internal view returns (IBloomPool) {
        return IBloomPool(bloomFactory.getLastCreatedPool());
    }

    /**
     * @notice Creates a withdrawal request and mints a redemption NFT to 
     * the redeemer
     * @param _account The address of the account redeeming their stUSD
     * @param _shares The amount of shares to redeem
     */
    function _mintRedemptionNFT(address _account, uint256 _shares) internal returns (uint256) {
        return redemptionNFT.addWithdrawalRequest(_account, _shares);
    }
    
    /**
     * @notice Calculates the current value of all TBYs that are staked in stUSD
     */
    function _getCurrentTbyValue() internal view returns (uint256) {
        address[] memory tokens = registry.getActiveTokens();
        
        uint256 usdValue;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));
            usdValue += tokenBalance * registry.getExchangeRate(tokens[i]) / 1e6;
        }

        return usdValue * 1e12;
    }
}
