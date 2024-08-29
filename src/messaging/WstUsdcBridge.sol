// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {IOFT, SendParam, MessagingReceipt, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {IOAppComposer, ILayerZeroComposer} from "@LayerZero/oapp/interfaces/IOAppComposer.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {WstUsdcLite} from "../token/WstUsdcLite.sol";
import {StUsdcLite} from "../token/StUsdcLite.sol";

import {IWstUsdcBridge} from "../interfaces/IWstUsdcBridge.sol";

import {OAppController} from "./controllers/OAppController.sol";

/**
 * @title WstUsdcBridge
 * @notice Contract used for bridging wstUsdc between chains
 */
contract WstUsdcBridge is IWstUsdcBridge, OAppController, IOAppComposer {
    using OFTComposeMsgCodec for address;

    // =================== Storage ===================

    /// @notice Address of stUsdc contract
    address private immutable _stUsdc;

    /// @notice Address of wstUsdc contract
    WstUsdcLite private immutable _wstUsdc;

    /// @notice mapping of LayerZero Endpoint IDs to WstUsdcBridge instances
    mapping(uint32 => address) private _wstUsdcBridges;

    // ================= Constructor =================

    constructor(address wstUsdc, address layerZeroEndpoint, address bridgeOperator)
        OAppController(layerZeroEndpoint, bridgeOperator)
    {
        _wstUsdc = WstUsdcLite(wstUsdc);
        _stUsdc = address(WstUsdcLite(wstUsdc).getStUsdc());
    }

    // =================== Functions ===================

    /// @inheritdoc IWstUsdcBridge
    function bridgeWstUsdc(address destinationAddress, uint256 wstUsdcAmount, uint32 dstEid, LzSettings calldata settings)
        external
        payable
        returns (LzBridgeReceipt memory bridgingReceipt)
    {
        _wstUsdc.transferFrom(msg.sender, address(this), wstUsdcAmount);
        uint256 stUsdcAmount = _wstUsdc.unwrap(wstUsdcAmount);

        bridgingReceipt = _bridgeStUsdc(destinationAddress, stUsdcAmount, dstEid, settings);

        emit WstUsdcBridged(endpoint.eid(), dstEid, wstUsdcAmount);
    }

    /// @inheritdoc IWstUsdcBridge
    function wstUsdcBridge(uint32 eid, address bridge) external override onlyBridgeOperator {
        if (eid == 0) revert Errors.InvalidPeerID();
        if (bridge == address(0)) revert Errors.ZeroAddress();
        _wstUsdcBridges[eid] = bridge;
    }

    /// @inheritdoc IWstUsdcBridge
    function stUsdc() external view returns (address) {
        return _stUsdc;
    }

    /// @inheritdoc IWstUsdcBridge
    function wstUsdc() external view returns (address) {
        return address(_wstUsdc);
    }

    /// @inheritdoc IWstUsdcBridge
    function bridgeByEid(uint32 eid) external view returns (address) {
        return _wstUsdcBridges[eid];
    }

    /**
     * @notice Bridges stUsdc tokens to the destination wstUsdc Bridge contract
     * @param destinationAddress The address to send the bridged wstUsdc to
     * @param stUsdcAmount The unwrapped amount of stUsdc to bridge
     * @param dstEid The destination LayerZero Endpoint ID
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function _bridgeStUsdc(address destinationAddress, uint256 stUsdcAmount, uint32 dstEid, LzSettings calldata settings)
        internal
        returns (LzBridgeReceipt memory bridgingReceipt)
    {
        SendParam memory sendParam = _setSendParam(destinationAddress, stUsdcAmount, dstEid, settings.options);

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            IOFT(_stUsdc).send{value: msg.value}(sendParam, settings.fee, settings.refundRecipient);

        bridgingReceipt = LzBridgeReceipt(msgReceipt, oftReceipt);
    }

    /**
     * @notice Delivers wstUsdc tokens to the destination address
     * @param destinationAddress The address to send the bridged wstUsdc to
     * @param stUsdcAmount The unwrapped amount of stUsdc to be wrapped
     */
    function _deliverWstUsdc(address destinationAddress, uint256 stUsdcAmount) internal returns (bool) {
        IERC20(_stUsdc).approve(address(_wstUsdc), stUsdcAmount);
        uint256 wstUsdcAmount = _wstUsdc.wrap(stUsdcAmount);
        return _wstUsdc.transfer(destinationAddress, wstUsdcAmount);
    }

    /**
     * @notice Sets the send parameters for the bridging operation
     * @param destinationAddress The address to send the tokens to
     * @param amount The minimum amount of tokens to send
     * @param dstEid The destination LayerZero Endpoint ID
     * @param options The executor options for the send operation
     */
    function _setSendParam(address destinationAddress, uint256 amount, uint32 dstEid, bytes calldata options)
        internal
        view
        returns (SendParam memory)
    {
        return SendParam({
            dstEid: dstEid,
            to: _wstUsdcBridges[dstEid].addressToBytes32(),
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
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*Executor*/
        bytes calldata /*Executor Data*/
    ) external payable override {
        if (_oApp != _stUsdc) revert Errors.InvalidOApp();
        if (msg.sender != address(endpoint)) revert Errors.UnauthorizedCaller();

        bytes memory _composeMsgContent = OFTComposeMsgCodec.composeMsg(_message);

        (address destinationAddress, uint256 stUsdcAmount) = abi.decode(_composeMsgContent, (address, uint256));

        bool success = _deliverWstUsdc(destinationAddress, stUsdcAmount);
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
