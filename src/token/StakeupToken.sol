// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AllocatedToken} from "./AllocatedToken.sol";

contract StakeupToken is AllocatedToken {

    constructor(
        TokenRecipient[] memory startupRecipients,
        TokenRecipient[] memory investorRecipients,
        TokenRecipient[] memory operatorRecipients,
        TokenRecipient[] memory airdropRecipients,
        address _layerZeroEndpoint
    )
        AllocatedToken(
            startupRecipients,
            investorRecipients,
            operatorRecipients,
            airdropRecipients,
            _layerZeroEndpoint
        )
    {
        
    }
}
