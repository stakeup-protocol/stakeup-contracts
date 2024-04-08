// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOFT, SendParam, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OApp, Origin, OAppReceiver} from "@LayerZero/oapp/OApp.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStakingBase} from "../interfaces/IStakeupStakingBase.sol";

contract StakeupStakingL2 is OApp, IStakeupStakingBase {
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;

    /// @notice StTBY token instance
    IStTBY private immutable _stTBY;

    /// @notice StakeUp Token instance
    IStakeupToken private immutable _stakeupToken;

    /// @notice The address of StakeUp Staking's mainnet instance
    address private immutable _baseChainInstance;

    /// @notice Only the reward token can call this function
    modifier authorized() {
        if (msg.sender != address(_stTBY)) revert UnauthorizedCaller();
        _;
    }

    constructor(
        address stakeupToken,
        address stTBY,
        address baseChainInstance,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) OApp(layerZeroEndpoint, layerZeroDelegate) {
        _stakeupToken = IStakeupToken(stakeupToken);
        _stTBY = IStTBY(stTBY);
        _baseChainInstance = baseChainInstance;
    }

    /// @inheritdoc IStakeupStakingBase
    function processFees() external payable override authorized {
        //Get the balance of stTBY in the contract
        uint256 stTbyBalance = IERC20(address(_stTBY)).balanceOf(address(this));

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(20000000, 0)
            .addExecutorLzComposeOption(0, 50000000, 0);

        bytes memory composeMsg = abi.encodeCall(IStakeupStakingBase.processFees, ());
        SendParam memory sendParam = SendParam({
            dstEid: 1, // Mainnet chain ID
            to: _baseChainInstance.addressToBytes32(),
            amountLD: stTbyBalance,
            minAmountLD: stTbyBalance,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(address(_stTBY)).quoteSend(sendParam, false);
        
        IOFT(address(_stTBY)).send{ value: fee.nativeFee }(sendParam, fee, tx.origin);
    }

    /// @inheritdoc IStakeupStakingBase
    function getStakupToken() external view override returns (IStakeupToken) {
        return _stakeupToken;
    }

    /// @inheritdoc IStakeupStakingBase
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }

    /// @inheritdoc OAppReceiver
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {}
}