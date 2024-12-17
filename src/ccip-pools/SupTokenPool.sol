// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pool} from "@chainlink-ccip/libraries/Pool.sol";
import {BurnMintTokenPool} from "@chainlink-ccip/pools/BurnMintTokenPool.sol";
import {IBurnMintERC20} from "@chainlink-shared/token/ERC20/IBurnMintERC20.sol";
import {IStakeUpToken} from "@StakeUp/interfaces/IStakeUpToken.sol";

/**
 * @title SupTokenPool
 * @notice A Chainlink CCIP compatible bridge for Sup tokens.
 */
contract SupTokenPool is BurnMintTokenPool {

    // =================== Constructor ===================
    
    constructor(IStakeUpToken token, address[] memory allowlist, address rmnProxy, address router)
        BurnMintTokenPool(IBurnMintERC20(address(token)), allowlist, rmnProxy, router)
    {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== Functions ===================
    
    /// @notice Mint tokens from the pool to the recipient
    /// @dev The _validateReleaseOrMint check is an essential security check
    /// @dev Only change in this function is calling the mintFromPool function on SUP
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);

        // Only Change in this function
        IStakeUpToken(address(i_token)).mintFromPool(releaseOrMintIn.receiver, releaseOrMintIn.amount);

        emit Minted(msg.sender, releaseOrMintIn.receiver, releaseOrMintIn.amount);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }

    /// @notice Burns SUP tokens from the pool
    function _burn(uint256 amount) internal override {
        IStakeUpToken(address(i_token)).burnFromPool(amount);
    }
}
