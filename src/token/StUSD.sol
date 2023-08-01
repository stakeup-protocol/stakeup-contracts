// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Staked USD Contract
contract StUSD is ERC20, Ownable, Pausable {
    /*************************************/
    /************** Storage **************/
    /*************************************/

    /// @dev Mapping of TBY to bool
    mapping(address => bool) internal _whitelisted;

    /************************************/
    /************** Events **************/
    /************************************/

    /// @notice Emitted when new TBY is whitelisted
    /// @param tby TBY address
    /// @param whitelist whitelisted or not
    event TBYWhitelisted(address tby, bool whitelist);

    /*************************************/
    /************ Constructor ************/
    /*************************************/

    /// @notice Constructor
    constructor() ERC20("Staked USD", "stUSD") {}

    /************************************/
    /********** User Functions **********/
    /************************************/

    function depositTBY(uint256 _amount) external whenNotPaused {}

    /*************************************/
    /********** Owner Functions **********/
    /*************************************/

    /// @notice Whitelist TBY
    /// @dev Restricted to owner only
    /// @param _tby TBY address
    /// @param _whitelist whitelisted or not
    function whitelistTBY(address _tby, bool _whitelist) external onlyOwner {
        require(_tby != address(0), "!tby");
        _whitelisted[_tby] = _whitelist;
        emit TBYWhitelisted(_tby, _whitelist);
    }

    /// @notice Pause the contract
    /// @dev Restricted to owner only
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    /// @dev Restricted to owner only
    function unpause() external onlyOwner {
        _unpause();
    }

    /************************************/
    /******** Internal Functions ********/
    /************************************/
}
