// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {IOFT, SendParam, MessagingReceipt, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {IOAppComposer, ILayerZeroComposer} from "@LayerZero/oapp/interfaces/IOAppComposer.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {WstTBYBase} from "../token/WstTBYBase.sol";
import {StTBYBase} from "../token/StTBYBase.sol";

import {IWstTBYBridge} from "../interfaces/IWstTBYBridge.sol";

/**
 * @title WstTBYBridge
 * @notice Contract used for bridging wstTBY between chains
 */
contract WstTBYBridge is IWstTBYBridge, OApp, IOAppComposer {
    using OFTComposeMsgCodec for address;

    // =================== Storage ===================

    /// @notice Address of stTBY contract
    address private immutable _stTBY;

    /// @notice Address of wstTBY contract
    WstTBYBase private immutable _wstTBY;

    /// @notice Account that is allowed to set wstTBY bridge addresses
    address private immutable _bridgeOperator;

    /// @notice mapping of LayerZero Endpoint IDs to WstTBYBridge instances
    mapping(uint32 => address) private _wstTBYBridges;

    // =================== Modifiers ===================

    modifier onlyBridgeOperator() {
        if (msg.sender != _bridgeOperator) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================

    constructor(
        address wstTBY,
        address layerZeroEndpoint,
        address layerZeroDelegate,
        address bridgeOperator
    ) OApp(layerZeroEndpoint, layerZeroDelegate) {
        _wstTBY = WstTBYBase(wstTBY);
        _stTBY = address(WstTBYBase(wstTBY).getStTBY());
        _bridgeOperator = bridgeOperator;
    }

    // =================== Functions ===================

    /// @inheritdoc IWstTBYBridge
    function bridgeWstTBY(
        address destinationAddress,
        uint256 wstTBYAmount,
        uint32 dstEid,
        LzSettings calldata settings
    ) external payable returns (LzBridgeReceipt memory bridgingReceipt) {
        _wstTBY.transferFrom(msg.sender, address(this), wstTBYAmount);
        uint256 stTBYAmount = _wstTBY.unwrap(wstTBYAmount);

        return _bridgeStTBY(destinationAddress, stTBYAmount, dstEid, settings);
    }

    /// @inheritdoc IWstTBYBridge
    function setWstTBYBridge(
        uint32 eid,
        address bridgeAddress
    ) external override onlyBridgeOperator {
        if (bridgeAddress == address(0)) revert Errors.ZeroAddress();
        _wstTBYBridges[eid] = bridgeAddress;
    }

    /// @inheritdoc IWstTBYBridge
    function getStTBY() external view returns (address) {
        return _stTBY;
    }

    /// @inheritdoc IWstTBYBridge
    function getWstTBY() external view returns (address) {
        return address(_wstTBY);
    }

    /// @inheritdoc IWstTBYBridge
    function getBridgeByEid(uint32 eid) external view returns (address) {
        return _wstTBYBridges[eid];
    }

    /// @inheritdoc IWstTBYBridge
    function getBridgeOperator() external view returns (address) {
        return _bridgeOperator;
    }

    /**
     * @notice Bridges stTBY tokens to the destination wstTBY Bridge contract
     * @param destinationAddress The address to send the bridged wstTBY to
     * @param stTBYAmount The unwrapped amount of stTBY to bridge
     * @param dstEid The destination LayerZero Endpoint ID
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function _bridgeStTBY(
        address destinationAddress,
        uint256 stTBYAmount,
        uint32 dstEid,
        LzSettings calldata settings
    ) internal returns (LzBridgeReceipt memory bridgingReceipt) {
        SendParam memory sendParam = _setSendParam(
            destinationAddress,
            stTBYAmount,
            dstEid,
            settings.options
        );

        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = IOFT(_stTBY).send{value: msg.value}(
                sendParam,
                settings.fee,
                settings.refundRecipient
            );

        bridgingReceipt = LzBridgeReceipt(msgReceipt, oftReceipt);
    }

    /**
     * @notice Delivers wstTBY tokens to the destination address
     * @param destinationAddress The address to send the bridged wstTBY to
     * @param stTBYAmount The unwrapped amount of stTBY to be wrapped
     */
    function _deliverWstTBY(
        address destinationAddress,
        uint256 stTBYAmount
    ) internal returns (bool) {
        IERC20(_stTBY).approve(address(_wstTBY), stTBYAmount);
        uint256 wstTBYAmount = _wstTBY.wrap(stTBYAmount);
        return _wstTBY.transfer(destinationAddress, wstTBYAmount);
    }

    /**
     * @notice Sets the send parameters for the bridging operation
     * @param destinationAddress The address to send the tokens to
     * @param amount The minimum amount of tokens to send
     * @param dstEid The destination LayerZero Endpoint ID
     * @param options The executor options for the send operation
     */
    function _setSendParam(
        address destinationAddress,
        uint256 amount,
        uint32 dstEid,
        bytes calldata options
    ) internal view returns (SendParam memory) {
        return
            SendParam({
                dstEid: dstEid,
                to: _wstTBYBridges[dstEid].addressToBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: options,
                composeMsg: abi.encode(destinationAddress, amount),
                oftCmd: ""
            });
    }

    /// @inheritdoc ILayerZeroComposer
    function lzCompose(
        address _oApp,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*Executor*/,
        bytes calldata /*Executor Data*/
    ) external payable override {
        if (_oApp != _stTBY) revert Errors.InvalidOApp();
        if (msg.sender != address(endpoint)) revert Errors.UnauthorizedCaller();

        bytes memory _composeMsgContent = OFTComposeMsgCodec.composeMsg(
            _message
        );

        (address destinationAddress, uint256 stTBYAmount) = abi.decode(
            _composeMsgContent,
            (address, uint256)
        );

        bool success = _deliverWstTBY(destinationAddress, stTBYAmount);
        if (!success) revert Errors.LZComposeFailed();
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {}
}
