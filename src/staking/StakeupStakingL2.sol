// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OApp, Origin, OAppReceiver} from "@LayerZero/oapp/OApp.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";

import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStakingBase} from "../interfaces/IStakeupStakingBase.sol";
import {IStTBY} from "../interfaces/IStTBY.sol";

/**
 * @title StakeupStakingL2
 * @notice Bridges stTBY fees to the mainnet StakeUp Staking contract
 */
contract StakeupStakingL2 is OApp, IStakeupStakingBase {
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;

    /// @notice StTBY token instance
    IStTBY private immutable _stTBY;

    /// @notice StakeUp Token instance
    IStakeupToken private immutable _stakeupToken;

    /// @notice The address of StakeUp Staking's mainnet instance
    address private immutable _baseChainInstance;

    /// @notice The endpoint ID of the mainnet chain
    uint32 private immutable _baseChainEid;

    bytes constant public PROCESS_FEE_MSG = abi.encodeCall(
        IStakeupStakingBase.processFees, 
        ((address(0)), LZBridgeSettings({ options: "", fee: MessagingFee({ nativeFee: 0, lzTokenFee: 0 })}))
    );

    /// @notice Only the reward token can call this function
    modifier authorized() {
        if (msg.sender != address(_stTBY)) revert UnauthorizedCaller();
        _;
    }

    constructor(
        address stakeupToken,
        address stTBY,
        address baseChainInstance,
        uint32 baseChainEid,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) OApp(layerZeroEndpoint, layerZeroDelegate) {
        _stakeupToken = IStakeupToken(stakeupToken);
        _stTBY = IStTBY(stTBY);
        _baseChainInstance = baseChainInstance;
        _baseChainEid = baseChainEid;
    }

    /// @inheritdoc IStakeupStakingBase
    function processFees(address refundRecipient, LZBridgeSettings memory settings)
        external
        payable
        override
        authorized
        returns (LzBridgeReceipt memory bridgingReceipt)
    {
        //Get the balance of stTBY in the contract
        uint256 stTbyBalance = IERC20(address(_stTBY)).balanceOf(address(this));

        SendParam memory sendParam = _setSendParam(stTbyBalance, settings.options);
        
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = IOFT(address(_stTBY)).send{ value: msg.value }(
            sendParam,
            settings.fee,
            refundRecipient
        );

        bridgingReceipt = LzBridgeReceipt(msgReceipt, oftReceipt);
    }

    /// @inheritdoc IStakeupStakingBase
    function getStakupToken() external view override returns (IStakeupToken) {
        return _stakeupToken;
    }

    /// @inheritdoc IStakeupStakingBase
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }

    /**
     * @notice Sets the send parameters for the bridging operation
     * @param amount The minimum amount of tokens to send
     * @param options The executor options for the send operation
     */
    function _setSendParam(uint256 amount, bytes memory options) internal view returns (SendParam memory) {
        return SendParam({
            dstEid: _baseChainEid,
            to: _baseChainInstance.addressToBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: PROCESS_FEE_MSG,
            oftCmd: ""
        });
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