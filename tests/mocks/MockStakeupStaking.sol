// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {MessagingFee, MessagingReceipt, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IStakeupStaking} from "src/interfaces/IStakeupStaking.sol";
import {IStakeupToken} from "src/interfaces/IStakeupToken.sol";
import {IStTBY} from "src/interfaces/IStTBY.sol";

contract MockStakeupStaking is IStakeupStaking {
    address private _stTBY;
    bool private _feeProcessed;

    function stake(uint256 stakeupAmount) external override {}

    function unstake(
        uint256 stakeupAmount,
        bool harvestRewards
    ) external override {}

    function harvest() external override {}

    function claimableRewards(
        address account
    ) external view override returns (uint256) {}

    function getStakupToken() external view override returns (IStakeupToken) {}

    function getStTBY() external view override returns (IStTBY) {
        return IStTBY(_stTBY);
    }

    function setStTBY(address stTBY) external {
        _stTBY = stTBY;
    }

    function totalStakeUpStaked() external view override returns (uint256) {}

    function getRewardData()
        external
        view
        override
        returns (RewardData memory)
    {}

    function getUserStakingData(
        address user
    ) external view override returns (StakingData memory) {}

    // This function is only used for unit testing
    function setFeeProcessed(bool feeProcessed) external {
        _feeProcessed = feeProcessed;
    }

    // This function is only used for unit testing
    function isFeeProcessed() external view returns (bool) {
        return _feeProcessed;
    }

    function getAvailableTokens(
        address account
    ) external view override returns (uint256) {}

    function vestTokens(address account, uint256 amount) external override {}

    function claimAvailableTokens() external override returns (uint256) {}

    function getCurrentBalance(
        address account
    ) external view override returns (uint256) {}

    function getLastRewardBlock() external view override returns (uint256) {}

    function processFees(
        address /*refundRecipient*/,
        LZBridgeSettings memory /*settings*/
    )
        external
        payable
        override
        returns (LzBridgeReceipt memory bridgingReceipt)
    {
        _feeProcessed = true;
        MessagingReceipt memory msgReceipt = MessagingReceipt(
            "",
            0,
            MessagingFee(0, 0)
        );
        OFTReceipt memory oftReceipt = OFTReceipt(0, 0);

        bridgingReceipt = LzBridgeReceipt(msgReceipt, oftReceipt);
    }
}
