// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

contract MockEndpoint {
    mapping(address oapp => address delegate) public delegates;

    function setDelegate(address delegate) external {
        delegates[msg.sender] = delegate;
    }
}
