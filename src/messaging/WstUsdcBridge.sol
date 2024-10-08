// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Origin} from "@LayerZero/oapp/OApp.sol";
import {IOFT, SendParam, MessagingReceipt, OFTReceipt, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {IOAppComposer, ILayerZeroComposer} from "@LayerZero/oapp/interfaces/IOAppComposer.sol";

import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {OAppController} from "@StakeUp/messaging/controllers/OAppController.sol";
import {WstUsdcLite} from "@StakeUp/token/WstUsdcLite.sol";
import {IStUsdcLite} from "@StakeUp/interfaces/IStUsdcLite.sol";
import {IWstUsdcBridge} from "@StakeUp/interfaces/IWstUsdcBridge.sol";

/**
 * @title WstUsdcBridge
 * @notice Contract used for bridging wstUsdc between chains
 */
contract WstUsdcBridge is IWstUsdcBridge, OAppController, IOAppComposer {
    using OFTComposeMsgCodec for bytes32;

    // =================== Storage ===================
    /// @notice mapping of LayerZero Endpoint IDs to WstUsdcBridge instances
    mapping(uint32 => bytes32) private _wstUsdcBridges;

    // =================== Immutables ===================
    /// @notice Address of stUsdc contract
    address private immutable _stUsdc;

    /// @notice Address of wstUsdc contract
    WstUsdcLite private immutable _wstUsdc;

    // ================= Constructor =================
    constructor(address wstUsdc_, address layerZeroEndpoint, address bridgeOperator)
        OAppController(layerZeroEndpoint, bridgeOperator)
    {
        _wstUsdc = WstUsdcLite(wstUsdc_);
        _stUsdc = address(WstUsdcLite(wstUsdc_).stUsdc());
    }

    // =================== Functions ===================
    /// @inheritdoc IWstUsdcBridge
    function bridgeWstUsdc(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 wstUsdcAmount,
        LzSettings calldata settings
    ) external payable returns (LzBridgeReceipt memory bridgingReceipt) {
        require(destinationAddress != bytes32(0), Errors.ZeroAddress());
        require(wstUsdcAmount > 0, Errors.ZeroAmount());

        _wstUsdc.transferFrom(msg.sender, address(this), wstUsdcAmount);
        uint256 stUsdcAmount = _wstUsdc.unwrap(wstUsdcAmount);

        emit WstUsdcBridged(endpoint.eid(), dstEid, wstUsdcAmount);
        bridgingReceipt = _bridgeStUsdc(dstEid, destinationAddress, stUsdcAmount, wstUsdcAmount, settings);
    }

    /// @inheritdoc IWstUsdcBridge
    function setWstUsdcBridge(uint32 eid, bytes32 bridge) external override onlyBridgeOperator {
        require(eid != 0, Errors.InvalidPeerID());
        require(bridge != bytes32(0), Errors.ZeroAddress());
        _wstUsdcBridges[eid] = bridge;
        emit WstUsdcBridgeSet(eid, bridge);
    }

    /// @inheritdoc IWstUsdcBridge
    function quoteBridgeWstUsdc(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 wstUsdcAmount,
        bytes calldata options
    ) external view returns (MessagingFee memory fee) {
        uint256 stUsdcAmount = IStUsdcLite(_stUsdc).usdByShares(wstUsdcAmount);
        SendParam memory sendParam = _setSendParam(dstEid, destinationAddress, stUsdcAmount, wstUsdcAmount, options);
        return IOFT(_stUsdc).quoteSend(sendParam, false);
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
    function bridgeByEid(uint32 eid) external view returns (bytes32) {
        return _wstUsdcBridges[eid];
    }

    /**
     * @notice Bridges stUsdc tokens to the destination wstUsdc Bridge contract
     * @param dstEid The destination LayerZero Endpoint ID
     * @param destinationAddress The address to send the bridged wstUsdc to (casted to bytes32)
     * @param stUsdcAmount The unwrapped amount of stUsdc to bridge
     * @param wstUsdcAmount The amount of wstUsdc to bridge
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function _bridgeStUsdc(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 stUsdcAmount,
        uint256 wstUsdcAmount,
        LzSettings calldata settings
    ) internal returns (LzBridgeReceipt memory bridgingReceipt) {
        SendParam memory sendParam =
            _setSendParam(dstEid, destinationAddress, stUsdcAmount, wstUsdcAmount, settings.options);

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            IOFT(_stUsdc).send{value: msg.value}(sendParam, settings.fee, settings.refundRecipient);

        bridgingReceipt = LzBridgeReceipt(msgReceipt, oftReceipt);
    }

    /**
     * @notice Delivers wstUsdc tokens to the destination address
     * @param destinationAddress The address to send the bridged wstUsdc to
     * @param wstUsdcAmount The wrapped amount of wstUsdc to deliver (Same as shares of wstUsdc to wrap)
     */
    function _deliverWstUsdc(address destinationAddress, uint256 wstUsdcAmount) internal returns (bool) {
        uint256 stUsdcAmount = IStUsdcLite(_stUsdc).usdByShares(wstUsdcAmount);
        IERC20(_stUsdc).approve(address(_wstUsdc), stUsdcAmount);
        wstUsdcAmount = _wstUsdc.wrap(stUsdcAmount);
        return _wstUsdc.transfer(destinationAddress, wstUsdcAmount);
    }

    /**
     * @notice Sets the send parameters for the bridging operation
     * @param dstEid The destination LayerZero Endpoint ID
     * @param destinationAddress The address to send the tokens to (casted to bytes32)
     * @param amount The minimum amount of tokens to send
     * @param options The executor options for the send operation
     */
    function _setSendParam(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 amount,
        uint256 wstUsdcAmount,
        bytes calldata options
    ) internal view returns (SendParam memory) {
        bytes32 wstUsdcBridge = _wstUsdcBridges[dstEid];
        require(wstUsdcBridge != bytes32(0), Errors.ZeroAddress());

        return SendParam({
            dstEid: dstEid,
            to: wstUsdcBridge,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: abi.encode(destinationAddress, wstUsdcAmount),
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

        (bytes32 destinationAddressBytes32, uint256 wstUsdcAmount) = abi.decode(_composeMsgContent, (bytes32, uint256));
        address destinationAddress = destinationAddressBytes32.bytes32ToAddress();

        bool success = _deliverWstUsdc(destinationAddress, wstUsdcAmount);
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
