// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Interface defining INFTDescriptor to generate ERC721 tokenURI
interface INFTDescriptor {
    /// @notice Returns ERC721 tokenURI content
    /// @param _requestId is an id for particular withdrawal request
    function constructTokenURI(uint256 _requestId) external view returns (string memory);
}
