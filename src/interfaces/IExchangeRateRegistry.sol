// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.19;

interface IExchangeRateRegistry {
    /**
     * @notice Returns the current information for the given TBY token
     * @param registered True if the token is registered
     * @param active True if the token is active
     * @param createdAt The timestamp at which the token was registered
     */
    struct TokenInfo {
        bool registered;
        bool active;
        uint256 createdAt;
    }

    /**
     * @notice Retrieves the current information for the given TBY token
     * @param token The address of the TBY token to query
     */
    function tokenInfos(address token) external view returns (TokenInfo memory);

}