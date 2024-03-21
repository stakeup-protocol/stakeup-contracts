// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {RedemptionNFT} from "../../src/token/RedemptionNFT.sol";

contract RedemptionNFTHarness is RedemptionNFT { 
    
    constructor(
        string memory name,
        string memory symbol,
        address stTBY,
        address lzEndpoint
    ) RedemptionNFT(name, symbol, stTBY, lzEndpoint) { }

    function decodePayload(bytes memory _payload) external view returns (address toAddress, uint256[] memory tokenIds, uint256[] memory amountOfShares) {
        bytes memory toAddressBytes;
        (toAddressBytes, tokenIds, amountOfShares) = abi.decode(_payload, (bytes, uint256[], uint256[]));

        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }
    }
}
