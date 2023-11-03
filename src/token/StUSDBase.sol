// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OFTV2} from "@layerzerolabs/token/oft/v2/OFTV2.sol";
import {IStUSD} from "../interfaces/IStUSD.sol";

/// @title Staked USD Base Contract
contract StUSDBase is IStUSD, OFTV2 {
    // =================== Constants ===================

    uint256 internal constant INFINITE_ALLOWANCE = type(uint256).max;

    // =================== Storage ===================

    /**
     * @dev StUSD balances are dynamic and are calculated based on the accounts' shares
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

    // =================== Events ===================

    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param sharesAmount Amount of shares transferred 
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesAmount);

    /**
     * @notice An executed `burnShares` request
     * @dev Reports simultaneously burnt shares amount
     * and corresponding stUSD amount.
     * The stUSD amount is calculated twice: before and after the burning incurred rebase.
     * @param account holder of the burnt shares
     * @param preRebaseTokenAmount amount of stUSD the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount amount of stUSD the burnt shares corresponded to after the burn
     * @param sharesAmount amount of burnt shares
    */
    event SharesBurnt(
        address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
    );

    /**
     * @notice Emitted when user deposits
     * @param account User address
     * @param tby TBY address
     * @param amount TBY deposit amount
     * @param shares Amount of shares minted to the user
     */
    event Deposit(address indexed account, address tby, uint256 amount, uint256 shares);

    // =================== Functions ===================

    constructor(address _layerZeroEndpoint) 
        OFTV2("Staked USD", "stUSD", 6, _layerZeroEndpoint)
    {
        // solhint-disable-next-line-no-empty-blocks
    }

    function circulatingSupply() public view override returns (uint) {
        return totalSupply();
    }

    /**
     * @notice Get the total supply of stUSD
     * @dev Always equals to `_getTotalUsd()` since token amount
     *  is pegged to the total amount of Usd controlled by the protocol.
     * @return Amount of tokens in existence
     */
    function totalSupply() public view override returns (uint256) {
        return _getTotalUsd();
    }

    /**
     * @return the entire amount of Usd controlled by the protocol.
     * @dev The sum of all USD balances in the protocol, equals to the total supply of stUSD.
     */
    function getTotalUsd() external view returns (uint256) {
        return _getTotalUsd();
    }

    /**
     * @notice Get the balance of an account
     * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
     * total Usd controlled by the protocol. See `sharesOf`.
     * @param _account Account to get balance of
     * @return Amount of tokens owned by the `_account`
     */
    function balanceOf(address _account) public view override returns (uint256) {
        return getUsdByShares(_sharesOf(_account));
    }

    /**
     * @notice Transfer tokens from caller to recipient
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * Requirements:
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * @param _recipient recipient of stUSD tokens
     * @param _amount Amount of tokens being transfered
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    /**
     * @notice Get the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     * @dev This value changes when `approve` or `transferFrom` is called.
     * @param _owner Owner of the tokens
     * @param _spender Spender of the tokens
     */
    function allowance(address _owner, address _spender) public view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @notice Set the allowance for `_spender`'s tokens to `_amount`
     * @dev Emits an `Approval` event.
     * Requirements:
     * - `_spender` cannot be the zero address.
     * @param _spender Spender of stUSD tokens
     * @param _amount Amount of stUSD tokens allowed to be spent
     */
    function approve(address _spender, uint256 _amount) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one account to another
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     * @dev Emits an `Approval` event indicating the updated allowance.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * Requirements:
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have a balance of at least `_amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     * @param _sender Sender of stUSD tokens
     * @param _recipient Destination of stUSD tokens
     * @param _amount Amount of tokens being transfered
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _spendAllowance(_sender, msg.sender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     * Requirements:
     * - `_spender` cannot be the zero address.
     * @param _spender The address which the allowance is increased for
     * @param _addedValue The additional amount of allowance to be granted
     */
    function increaseAllowance(address _spender, uint256 _addedValue) public override returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`.
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     * Requirements:
     * - `_spender` cannot be the zero address.
     * - `_spender` must have allowance for the caller of at least `_subtractedValue`.
     * @param _spender The address which the allowance is decreased for
     * @param _subtractedValue The amount of allowance to be reduced
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public override returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }

    /**
     * @notice Get the total amount of shares in existence.
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function getTotalShares() external view returns (uint256) {
        return _getTotalShares();
    }

    /**
     * @notice Get the amount of shares owned by `_account`
     * @param _account Account to get shares of
     */
    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @notice Get the amount of shares that corresponds to a given dollar value.
     * @param _usdAmount Amount of Usd
     */
    function getSharesByUsd(uint256 _usdAmount) public view override returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return _usdAmount;
        }
        return (_usdAmount * totalShares) / _getTotalUsd();
    }

    /// @return the amount of Usd that corresponds to `_sharesAmount` token shares.
    /**
     * @notice Get the amount of Usd that corresponds to a given number of token shares.
     * @param _sharesAmount Amount of shares
     */
    function getUsdByShares(uint256 _sharesAmount) public view override returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return _sharesAmount;
        }
        return (_sharesAmount * _getTotalUsd()) / totalShares;
    }

    /**
     * @notice Transfer shares from caller to recipient
     * @dev Emits a `TransferShares` event.
     * @dev Emits a `Transfer` event.
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
     * Requirements:
     * - `_recipient` cannot be the zero address.
     * - the caller must have at least `_sharesAmount` shares.
     * @param _recipient recipient of stUSD tokens
     * @param _sharesAmount Amount of shares being transfered
     */
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256) {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getUsdByShares(_sharesAmount);
        _emitTransferEvents(msg.sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }

    /**
     * @notice Transfer shares from one account to another
     * @dev Emits a `TransferShares` event.
     * @dev Emits a `Transfer` event.
     * Requirements:
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have at least `_sharesAmount` shares.
     * - the caller must have allowance for `_sender`'s tokens of at least `getUsdByShares(_sharesAmount)`.
     * @param _sender Sender of stUSD tokens
     * @param _recipient Destination of stUSD tokens
     * @param _sharesAmount Amount of shares being transfered
     */
    function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount)
        external
        returns (uint256)
    {
        uint256 tokensAmount = getUsdByShares(_sharesAmount);
        _spendAllowance(_sender, msg.sender, tokensAmount);
        _transferShares(_sender, _recipient, _sharesAmount);
        _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
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
     * @param _amount Amount
     */
    function _setTotalUsd(uint256 _amount) internal {
        _totalUsd = _amount;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * @dev Emits a `Transfer` event.
     * @dev Emits a `TransferShares` event.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal override {
        uint256 _sharesToTransfer = getSharesByUsd(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     * @dev Emits an `Approval` event.
     * Requirements:
     * - `_owner` cannot be the zero address.
     * - `_spender` cannot be the zero address. 
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal override {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDR");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal override {
        uint256 currentAllowance = _allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    /// @return the total amount of shares in existence.
    function _getTotalShares() internal view returns (uint256) {
        return _totalShares;
    }

    /// @return the amount of shares owned by `_account`.
    function _sharesOf(address _account) internal view returns (uint256) {
        return _shares[_account];
    }

    /**
     * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
     * @dev This doesn't change the token total supply.
     * Requirements:
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address.
     * - `_sender` must hold at least `_sharesAmount` shares.
     * @param _sender The sender of stUSD tokens
     * @param _recipient The recipient of stUSD tokens
     * @param _sharesAmount Amount of shares to transfer
     */
    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(_recipient != address(0), "TRANSFER_TO_ZERO_ADDR");

        uint256 currentSenderShares = _shares[_sender];
        require(_sharesAmount <= currentSenderShares, "BALANCE_EXCEEDED");

        _shares[_sender] = currentSenderShares - _sharesAmount;
        _shares[_recipient] = _shares[_recipient] + _sharesAmount;
    }

    /**
     * @notice  Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
     * @dev This doesn't increase the token total supply.
     * Requirements:
     * - `_recipient` cannot be the zero address.
     * @param _recipient Destination where minted shares will be sent
     * @param _sharesAmount Amount of shares to mint
     */
    function _mintShares(address _recipient, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), "MINT_TO_ZERO_ADDR");

        newTotalShares = _getTotalShares() + _sharesAmount;
        _totalShares = newTotalShares;

        _shares[_recipient] = _shares[_recipient] + _sharesAmount;

        // Notice: we're not emitting a Transfer event from the zero address here since shares mint
        // works by taking the amount of tokens corresponding to the minted shares from all other
        // token holders, proportionally to their share. The total supply of the token doesn't change
        // as the result. This is equivalent to performing a send from each other token holder's
        // address to `address`, but we cannot reflect this as it would require sending an unbounded
        // number of events.
    }

    /**
     * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
     * @dev This doesn't decrease the token total supply.
     *  Requirements:
     * - `_account` cannot be the zero address.
     * - `_account` must hold at least `_sharesAmount` shares.
     * @param _account Account to burn shares from
     * @param _sharesAmount Amount of shares to burn
     */
    function _burnShares(address _account, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
        require(_account != address(0), "BURN_FROM_ZERO_ADDR");

        uint256 accountShares = _shares[_account];
        require(_sharesAmount <= accountShares, "BALANCE_EXCEEDED");

        uint256 preRebaseTokenAmount = getUsdByShares(_sharesAmount);

        newTotalShares = _getTotalShares() - _sharesAmount;
        _totalShares = newTotalShares;

        _shares[_account] = accountShares - _sharesAmount;

        uint256 postRebaseTokenAmount = getUsdByShares(_sharesAmount);

        emit SharesBurnt(_account, preRebaseTokenAmount, postRebaseTokenAmount, _sharesAmount);

        // Notice: we're not emitting a Transfer event to the zero address here since shares burn
        // works by redistributing the amount of tokens corresponding to the burned shares between
        // all other token holders. The total supply of the token doesn't change as the result.
        // This is equivalent to performing a send from `address` to each other token holder address,
        // but we cannot reflect this as it would require sending an unbounded number of events.

        // We're emitting `SharesBurnt` event to provide an explicit rebase log record nonetheless.
    }

    /// @dev Emits {Transfer} and {TransferShares} events
    function _emitTransferEvents(address _from, address _to, uint256 _tokenAmount, uint256 _sharesAmount) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }
}
