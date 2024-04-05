// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStakingBase} from "../interfaces/IStakeupStakingBase.sol";

contract StakeupStakingL2 is IStakeupStakingBase {
    
    /// @notice StTBY token instance
    IStTBY private immutable _stTBY;

    /// @notice StakeUp Token instance
    IStakeupToken private immutable _stakeupToken;

    /// @notice The address of StakeUp Staking's mainnet instance
    address private immutable _baseChainInstance;

    constructor(
        address stakeupToken,
        address stTBY,
        address baseChainInstance
    ) {
        _stTBY = IStTBY(stTBY);
        _stakeupToken = IStakeupToken(stakeupToken);
        _baseChainInstance = baseChainInstance;
    }

    /// @inheritdoc IStakeupStakingBase
    function processFees() external override {
        // Get the balance of stTBY in the contract
        uint256 stTbyBalance = IERC20(address(_stTBY)).balanceOf(address(this));
        
        OFT(address(_stTBY)).sendFrom(
            address(this),
            1, // Mainnet chain ID
            _baseChainInstance,
            stTbyBalance,
            payable(address(msg.sender)),
            address(0),
            
        );
        // Bridge stTBY to Mainnet StakeUp Staking contract
            function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    )
        // Call the stTBY contract processFees function
    }

    /// @inheritdoc IStakeupStakingBase
    function getStakupToken() external view override returns (IStakeupToken) {
        return _stakeupToken;
    }

    /// @inheritdoc IStakeupStakingBase
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }
}