// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ONFT721} from "@layerzerolabs/token/onft721/ONFT721.sol";
import {IRedemptionNFT} from "../interfaces/IRedemptionNFT.sol";
import {IStUSD} from "../interfaces/IStUSD.sol";

contract RedemptionNFT is IRedemptionNFT, ONFT721 {
    address private _stUSD;
    uint256 private _mintCount;
    mapping(uint256 => WithdrawalRequest) private _withdrawalRequests;

    modifier onlyStUSD() {
        if (_msgSender() != _stUSD) revert CallerNotStUSD();
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address stUSD,
        address lzEndpoint
    ) ONFT721(name, symbol, 0, lzEndpoint) {
        _stUSD = stUSD;
    }

    function addWithdrawalRequest(
        address to,
        uint256 shares
    ) external override onlyStUSD returns (uint256) {
        uint256 tokenId = _mintCount;
        _mintCount += 1;

        _withdrawalRequests[tokenId] = WithdrawalRequest({
            amountOfShares: shares,
            owner: to,
            timestamp: uint40(block.timestamp),
            claimed: false
        });

        _mint(to, tokenId);

        return tokenId;
    }

    function claimWithdrawal(uint256 tokenId) external override {
        WithdrawalRequest storage request = _withdrawalRequests[tokenId];

        if (request.owner != _msgSender()) revert NotOwner();
        if (request.claimed) revert RedemptionClaimed();

        request.claimed = true;

        IStUSD(_stUSD).withdraw(request.owner, request.amountOfShares);
    }

    function getWithdrawalRequest(
        uint256 tokenId
    ) external view override returns (WithdrawalRequest memory) {
        return _withdrawalRequests[tokenId];
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        WithdrawalRequest storage request = _withdrawalRequests[tokenId];
        
        if (request.owner != from) revert NotOwner();
        if (request.claimed) revert RedemptionClaimed();

        request.owner = to;

        super._transfer(from, to, tokenId);
    }
}