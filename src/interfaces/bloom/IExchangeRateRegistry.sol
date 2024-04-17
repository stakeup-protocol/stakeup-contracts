// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.22;

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

    /**
     * @notice Return list of active tokens
     */
    function getActiveTokens() external view returns (address[] memory);

    /**
     * @notice Returns the current exchange rate of the given token
     * @dev Returns value as an 18 decimal fixed point number
     * @param token The token address
     * @return The current exchange rate of the given token
     */
    function getExchangeRate(address token) external view returns (uint256);
}
