// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pool} from "@chainlink-ccip/libraries/Pool.sol";
import {TokenPool, IERC20} from "@chainlink-ccip/pools/TokenPool.sol";
import {ITypeAndVersion} from "@chainlink/shared/interfaces/ITypeAndVersion.sol";

import {IStUsdcLite} from "@StakeUp/interfaces/IStUsdcLite.sol";
import {IWstUsdcLite} from "@StakeUp/interfaces/IWstUsdcLite.sol";

/**
 * @title StUsdcTokenPool
 * @notice A Chainlink CCIP compatible bridge for stUsdc and wstUsdc tokens.
 */
contract StUsdcTokenPool is TokenPool, ITypeAndVersion {
    // =================== Storage ===================

    /// @notice Type and version of the pool.
    string public constant override typeAndVersion = "StUsdcTokenPool 1.0.0";

    /// @notice The WstUsdc instance on the source chain.
    IWstUsdcLite public immutable _wstUsdc;

    // =================== Constructor ===================

    constructor(address token, IWstUsdcLite wstUsdc, address[] memory allowlist, address rmnProxy, address router)
        TokenPool(IERC20(token), allowlist, rmnProxy, router)
    {
        _wstUsdc = wstUsdc;
    }

    // =================== Functions ===================

    /// @notice Burn the token in the pool
    /// @dev The _validateLockOrBurn check is an essential security check
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        virtual
        override
        returns (Pool.LockOrBurnOutV1 memory)
    {
        address localToken = lockOrBurnIn.localToken;
        // This TokenPool accepts both WstUsdc and StUsdc. If the token is WstUsdc, we must unwrap it first.
        bool isWrapped = localToken == address(_wstUsdc);

        if (isWrapped) {
            // Set the local token to StUsdc since we will be burning and minting StUsdc before wrapping on the dst chain
            localToken = address(i_token);
            _validateLockOrBurn(lockOrBurnIn);
            _wstUsdc.unwrap(lockOrBurnIn.amount);
            _burnShares(lockOrBurnIn.amount);
        } else {
            uint256 shares = IStUsdcLite(localToken).sharesByUsd(lockOrBurnIn.amount);
            _burnShares(shares);
        }

        _validateLockOrBurn(lockOrBurnIn);

        emit Burned(msg.sender, lockOrBurnIn.amount);

        return Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(isWrapped)
        });
    }

    /// @notice Mint tokens from the pool to the recipient
    /// @dev The _validateReleaseOrMint check is an essential security check
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        virtual
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        bool isWrapped = abi.decode(releaseOrMintIn.sourcePoolData, (bool));

        if (isWrapped) {
            // Mint stUsdc shares and wrap them
            uint256 stUsdcAmount = _mintShares(address(this), releaseOrMintIn.amount);
            uint256 wstUsdcAmount = _wstUsdc.wrap(stUsdcAmount);
            _wstUsdc.transfer(releaseOrMintIn.receiver, wstUsdcAmount);
        } else {
            // Mint stUsdc shares
            _mintShares(releaseOrMintIn.receiver, releaseOrMintIn.amount);
        }

        _validateReleaseOrMint(releaseOrMintIn);

        emit Minted(msg.sender, releaseOrMintIn.receiver, releaseOrMintIn.amount);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }

    /**
     * @notice Mint shares to the recipient and return the amount of stUsdc minted
     * @param to The address to mint shares to
     * @param amount The amount of shares to mint
     * @return The amount of stUsdc minted
     */
    function _mintShares(address to, uint256 amount) internal returns (uint256) {
        uint256 beforeStUsdcAmount = IStUsdcLite(address(i_token)).balanceOf(address(this));
        IStUsdcLite(address(i_token)).mintShares(to, amount);
        uint256 afterStUsdcAmount = IStUsdcLite(address(i_token)).balanceOf(address(this));
        return afterStUsdcAmount - beforeStUsdcAmount;
    }

    /**
     * @notice Burn shares of stUsdc
     * @param amount The amount of shares to burn
     */
    function _burnShares(uint256 amount) internal {
        IStUsdcLite(address(i_token)).burnShares(amount);
    }
}
