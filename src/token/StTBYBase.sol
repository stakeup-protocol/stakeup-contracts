// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStTBYBase} from "../interfaces/IStTBYBase.sol";
import {OFTController} from "src/messaging/controllers/OFTController.sol";

/// @title Staked TBY Base Contract
contract StTBYBase is IStTBYBase, OFTController {
    using FixedPointMathLib for uint256;

    // =================== Storage ===================

    /**
     * @dev stTBY balances are dynamic and are calculated based on the accounts' shares
     * and the total amount of USD controlled by the protocol. Account shares aren't
     * normalized, so the contract also stores the sum of all shares to calculate
     * each account's token balance which equals to:
     *
     *   _shares[account] * _getTotalUsd() / _getTotalShares()
     */
    mapping(address => uint256) private _shares;

    /// @dev Allowances are nominated in tokens, not token shares.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @dev Total amount of shares
    uint256 internal _totalShares;

    /// @dev Total amount of Usd
    uint256 internal _totalUsd;

    /// @dev The total amount of stTBY shares in circulation on all chains
    uint256 internal _globalShares;

    /// @dev The address of the messenger contract
    address internal _messenger;

    // =================== Modifiers ===================

    modifier onlyMessenger() {
        if (msg.sender != _messenger) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================== Constructor ==================

    constructor(
        address messenger,
        address layerZeroEndpoint,
        address bridgeOperator
    ) OFTController("Staked TBY", "stTBY", layerZeroEndpoint, bridgeOperator) {
        if (messenger == address(0)) revert Errors.ZeroAddress();
        _messenger = messenger;
    }

    // =================== Functions ==================

    /// @inheritdoc IStTBYBase
    function setGlobalShares(uint256 newGlobalShares) external onlyMessenger {
        _setGlobalShares(newGlobalShares);
    }

    /// @inheritdoc IStTBYBase
    function accrueYield(uint256 amount) external onlyMessenger {
        _accrueYield(amount);
    }

    /// @inheritdoc IStTBYBase
    function removeYield(uint256 amount) external onlyMessenger {
        _accrueYield(amount);
    }

    /**
     * @notice Get the total supply of stTBY
     * @dev Always equals to `_getTotalUsd()` since token amount
     *  is pegged to the total amount of Usd controlled by the protocol.
     * @return Amount of tokens in existence
     */
    function totalSupply() public view override returns (uint256) {
        return _getTotalUsd();
    }

    /// @inheritdoc IStTBYBase
    function getTotalUsd() external view override returns (uint256) {
        return _getTotalUsd();
    }

    /**
     * @notice Get the balance of an account
     * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
     * total Usd controlled by the protocol. See `sharesOf`.
     * @param account Account to get balance of
     * @return Amount of tokens owned by the `_account`
     */
    function balanceOf(address account) public view override returns (uint256) {
        return getUsdByShares(_sharesOf(account));
    }

    /**
     * @notice Transfer tokens from caller to recipient
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * Requirements:
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * @param recipient recipient of stTBY tokens
     * @param amount Amount of tokens being transfered
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @notice Get the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     * @dev This value changes when `approve` or `transferFrom` is called.
     * @param owner Owner of the tokens
     * @param spender Spender of the tokens
     */
    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Set the allowance for `_spender`'s tokens to `_amount`
     * @dev Emits an `Approval` event.
     * Requirements:
     * - `_spender` cannot be the zero address.
     * @param spender Spender of stTBY tokens
     * @param amount Amount of stTBY tokens allowed to be spent
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one account to another
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     * @dev Emits an `Approval` event indicating the updated allowance.
     * @dev The `amount` argument is the amount of tokens, not shares.
     * Requirements:
     * - sender` and `recipient` cannot be the zero addresses.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least `amount`.
     * @param sender Sender of stTBY tokens
     * @param recipient Destination of stTBY tokens
     * @param amount Amount of tokens being transfered
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(sender, msg.sender, amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `spender` by the caller by `addedValue`.
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     * @param spender The address which the allowance is increased for
     * @param addedValue The additional amount of allowance to be granted
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public override returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `spender` by the caller by `subtractedValue`.
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least `subtractedValue`.
     * @param spender The address which the allowance is decreased for
     * @param subtractedValue The amount of allowance to be reduced
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /// @inheritdoc IStTBYBase
    function getTotalShares() external view override returns (uint256) {
        return _getTotalShares();
    }

    /// @inheritdoc IStTBYBase
    function sharesOf(
        address account
    ) external view override returns (uint256) {
        return _sharesOf(account);
    }

    /// @inheritdoc IStTBYBase
    function getSharesByUsd(
        uint256 usdAmount
    ) public view override returns (uint256) {
        uint256 totalShares = _getTotalShares();
        uint256 totalUsd = _getTotalUsd();

        if (totalShares == 0) {
            return usdAmount;
        }
        if (totalUsd == 0) {
            return totalShares;
        }

        return usdAmount.mulWad(totalShares).divWad(totalUsd);
    }

    /// @inheritdoc IStTBYBase
    function getUsdByShares(
        uint256 sharesAmount
    ) public view override returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return sharesAmount;
        }
        return sharesAmount.mulWadUp(_getTotalUsd()).divWadUp(totalShares);
    }

    /// @inheritdoc IStTBYBase
    function getGlobalShares() public view override returns (uint256) {
        return _globalShares;
    }

    /// @inheritdoc IStTBYBase
    function getSupplyIndex() public view override returns (uint256) {
        uint256 globalShares = getGlobalShares();
        if (globalShares == 0) {
            return 0;
        }
        return _getTotalShares().divWadUp(globalShares);
    }

    /// @inheritdoc IStTBYBase
    function getMessenger() external view override returns (address) {
        return _messenger;
    }

    /// @inheritdoc IStTBYBase
    function transferShares(
        address recipient,
        uint256 sharesAmount
    ) external returns (uint256) {
        _transferShares(msg.sender, recipient, sharesAmount);
        uint256 tokensAmount = getUsdByShares(sharesAmount);
        _emitTransferEvents(msg.sender, recipient, tokensAmount, sharesAmount);
        return tokensAmount;
    }

    /// @inheritdoc IStTBYBase
    function transferSharesFrom(
        address sender,
        address recipient,
        uint256 sharesAmount
    ) external returns (uint256) {
        uint256 tokensAmount = getUsdByShares(sharesAmount);
        _spendAllowance(sender, msg.sender, tokensAmount);
        _transferShares(sender, recipient, sharesAmount);
        _emitTransferEvents(sender, recipient, tokensAmount, sharesAmount);
        return tokensAmount;
    }

    /**
     * @dev This is used for calculating tokens from shares and vice versa.
     * @dev This function is required to be implemented in a derived contract.
     * @return Total amount of Usd controlled by the protocol
     */
    function _getTotalUsd() internal view returns (uint256) {
        return _totalUsd;
    }

    /**
     * @dev Set the total amount of Usd.
     * @param amount Amount
     */
    function _setTotalUsd(uint256 amount) internal virtual {
        _totalUsd = amount;
    }

    /**
     * @notice Moves `amount` tokens from `sender` to `recipient`.
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 sharesToTransfer = getSharesByUsd(amount);
        _transferShares(sender, recipient, sharesToTransfer);
        _emitTransferEvents(sender, recipient, amount, sharesToTransfer);
    }

    /**
     * @notice Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     * @dev Emits an `Approval` event.
     * Requirements:
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        require(owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(spender != address(0), "APPROVE_TO_ZERO_ADDR");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != Constants.MAX_UINT_256) {
            require(currentAllowance >= amount, "ALLOWANCE_EXCEEDED");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    /// @return the total amount of shares in existence.
    function _getTotalShares() internal view returns (uint256) {
        return _totalShares;
    }

    /// @return the amount of shares owned by `account`.
    function _sharesOf(address account) internal view returns (uint256) {
        return _shares[account];
    }

    /**
     * @notice Moves `sharesAmount` shares from `sender` to `recipient`.
     * @dev This doesn't change the token total supply.
     * Requirements:
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must hold at least `sharesAmount` shares.
     * @param sender The sender of stTBY tokens
     * @param recipient The recipient of stTBY tokens
     * @param sharesAmount Amount of shares to transfer
     */
    function _transferShares(
        address sender,
        address recipient,
        uint256 sharesAmount
    ) internal {
        require(sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(recipient != address(0), "TRANSFER_TO_ZERO_ADDR");

        uint256 currentSenderShares = _shares[sender];
        require(sharesAmount <= currentSenderShares, "BALANCE_EXCEEDED");

        _shares[sender] = currentSenderShares - sharesAmount;
        _shares[recipient] = _shares[recipient] + sharesAmount;
    }

    /**
     * @notice  Creates `sharesAmount` shares and assigns them to `recipient`, increasing the total amount of shares.
     * @dev This doesn't increase the token total supply.
     * Requirements:
     * - `recipient` cannot be the zero address.
     * @param recipient Destination where minted shares will be sent
     * @param sharesAmount Amount of shares to mint
     */
    function _mintShares(
        address recipient,
        uint256 sharesAmount
    ) internal virtual returns (uint256 newTotalShares) {
        require(recipient != address(0), "MINT_TO_ZERO_ADDR");

        newTotalShares = _getTotalShares() + sharesAmount;
        _totalShares = newTotalShares;

        _shares[recipient] = _shares[recipient] + sharesAmount;

        // Notice: we're not emitting a Transfer event from the zero address here since shares mint
        // works by taking the amount of tokens corresponding to the minted shares from all other
        // token holders, proportionally to their share. The total supply of the token doesn't change
        // as the result. This is equivalent to performing a send from each other token holder's
        // address to `address`, but we cannot reflect this as it would require sending an unbounded
        // number of events.
    }

    /**
     * @notice Destroys `sharesAmount` shares from `account`'s holdings, decreasing the total amount of shares.
     * @dev This doesn't decrease the token total supply.
     *  Requirements:
     * - `account` cannot be the zero address.
     * - `account` must hold at least `sharesAmount` shares.
     * @param account Account to burn shares from
     * @param sharesAmount Amount of shares to burn
     */
    function _burnShares(
        address account,
        uint256 sharesAmount
    ) internal virtual returns (uint256 newTotalShares) {
        require(account != address(0), "BURN_FROM_ZERO_ADDR");

        uint256 accountShares = _shares[account];
        require(sharesAmount <= accountShares, "BALANCE_EXCEEDED");

        uint256 preRebaseTokenAmount = getUsdByShares(sharesAmount);

        newTotalShares = _getTotalShares() - sharesAmount;
        _totalShares = newTotalShares;

        _shares[account] = accountShares - sharesAmount;

        uint256 postRebaseTokenAmount = getUsdByShares(sharesAmount);

        emit SharesBurnt(
            account,
            preRebaseTokenAmount,
            postRebaseTokenAmount,
            sharesAmount
        );

        // Notice: we're not emitting a Transfer event to the zero address here since shares burn
        // works by redistributing the amount of tokens corresponding to the burned shares between
        // all other token holders. The total supply of the token doesn't change as the result.
        // This is equivalent to performing a send from `address` to each other token holder address,
        // but we cannot reflect this as it would require sending an unbounded number of events.

        // We're emitting `SharesBurnt` event to provide an explicit rebase log record nonetheless.
    }

    /// @dev Emits {Transfer} and {TransferShares} events
    function _emitTransferEvents(
        address from,
        address to,
        uint256 tokenAmount,
        uint256 sharesAmount
    ) internal {
        emit Transfer(from, to, tokenAmount);
        emit TransferShares(from, to, sharesAmount);
    }

    /**
     * @notice Sets the total amount of shares in existence across all chains
     * @param shares Total amount of shares in existence across all chains
     */
    function _setGlobalShares(uint256 shares) internal {
        _globalShares = shares;
    }

    /// @dev This is called on the base chain before distributing yield to other chains
    function _accrueYield(uint256 amount) internal {
        uint256 yieldAccrued = getSupplyIndex().mulWad(amount);
        _setTotalUsd(_getTotalUsd() + yieldAccrued);
    }

    /// @dev This is called on the base chain before before removing yield from other chains
    function _removeYield(uint256 amount) internal {
        uint256 yieldRemoved = getSupplyIndex().mulWad(amount);
        _setTotalUsd(_getTotalUsd() - yieldRemoved);
    }

    function _debit(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(
            _amountLD,
            _minAmountLD,
            _dstEid
        );

        uint256 shares = getSharesByUsd(amountSentLD);
        _burnShares(msg.sender, shares);
        _setTotalUsd(_getTotalUsd() - amountSentLD);
    }

    function _credit(
        address _to,
        uint256 _amountToCreditLD,
        uint32 /*_srcEid*/
    ) internal override returns (uint256 amountReceivedLD) {
        _mintShares(_to, getSharesByUsd(_amountToCreditLD));
        _setTotalUsd(_getTotalUsd() + _amountToCreditLD);
        return _amountToCreditLD;
    }
}
