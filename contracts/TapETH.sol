// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./interfaces/ITapETH.sol";

interface Ipool {
    function rebase() external returns (uint256);
}

/**
 * @title Interest-bearing ERC20-like token for Tapio protocol
 * @author Nuts Finance Developer
 * @notice ERC20 token minted by the StableSwap pools.
 * @dev TapETH is ERC20 rebase token minted by StableSwap pools for liquidity providers.
 * TapETH balances are dynamic and represent the holder's share in the total amount
 * of tapETH controlled by the protocol. Account shares aren't normalized, so the
 * contract also stores the sum of all shares to calculate each account's token balance
 * which equals to:
 *
 *   shares[account] * _getTotalPooledEther() / _getTotalShares()
 * where the _getTotalPooledEther() returns the total supply of tapETH controlled by the protocol.
 */

contract TapETH is ITapETH {
    uint256 internal constant INFINITE_ALLOWANCE = ~uint256(0);

    uint256 private totalShares;
    uint256 private _totalSupply;
    address public governance;
    address public pendingGovernance;
    mapping(address => uint256) private shares;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) public isPool;
    address[] public pools;

    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );

    event SharesBurnt(
        address indexed account,
        uint256 preRebaseTokenAmount,
        uint256 postRebaseTokenAmount,
        uint256 sharesAmount
    );

    event GovernanceModified(address indexed governance);
    event GovernanceProposed(address indexed governance);
    event PoolAdded(address indexed pool);
    event PoolRemoved(address indexed pool);

    constructor(address _governance) {
        require(_governance != address(0), "TapETH: zero address");
        governance = _governance;
    }

    function proposeGovernance(address _governance) public {
        require(msg.sender == governance, "TapETH: no governance");
        pendingGovernance = _governance;
        emit GovernanceProposed(_governance);
    }

    function acceptGovernance() public {
        require(
            msg.sender == pendingGovernance,
            "TapETH: no pending governance"
        );
        governance = pendingGovernance;
        pendingGovernance = address(0);
        emit GovernanceModified(governance);
    }

    function addPool(address _pool) public {
        require(msg.sender == governance, "TapETH: no governance");
        require(_pool != address(0), "TapETH: zero address");
        require(!isPool[_pool], "TapETH: pool is already added");
        isPool[_pool] = true;
        pools.push(_pool);
        emit PoolAdded(_pool);
    }

    function removePool(address _pool) public {
        require(msg.sender == governance, "TapETH: no governance");
        require(isPool[_pool], "TapETH: pool doesn't exist");
        isPool[_pool] = false;
        emit PoolRemoved(_pool);
    }

    /**
     * @return the name of the token.
     */
    function name() external pure returns (string memory) {
        return "Tapio v1.5";
    }

    /**
     * @return the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external pure returns (string memory) {
        return "tapETH";
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @return the amount of tokens in existence.
     *
     * @dev Always equals to `_getTotalPooledEther()`: the total amount of
     * tapETH controlled by the protocol.
     */
    function totalSupply() external view returns (uint256) {
        return _getTotalPooledEther();
    }

    /**
     * @return the entire amount of tapETH controlled by the protocol.
     *
     * @dev The sum of all tapETH balances in the protocol, equals to the total supply of tapETH.
     */

    function getTotalPooledEther() external view returns (uint256) {
        return _getTotalPooledEther();
    }

    /**
     * @return the amount of tokens owned by the `_account`.
     *
     * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
     * total tapETH controlled by the protocol. See `sharesOf`.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return getPooledEthByShares(_sharesOf(_account));
    }

    /**
     * @notice Moves `_amount` tokens from the caller's account to the `_recipient`account.
     * @return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    /**
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     * @dev This value changes when `approve` or `transferFrom` is called.
     */
    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function approve(
        address _spender,
        uint256 _amount
    ) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     *
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     *
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        _spendAllowance(_sender, msg.sender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     */

    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) external returns (bool) {
        _approve(
            msg.sender,
            _spender,
            allowances[msg.sender][_spender] += _addedValue
        );
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) external returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(
            currentAllowance >= _subtractedValue,
            "TapETH:ALLOWANCE_BELOW_ZERO"
        );
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }

    /**
     * @return the total amount of shares in existence.
     *
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }

    /**
     * @notice This function is called only by a stableSwap pool to increase
     * the total supply of TapETH by the staking rewards and the swap fee.
     */
    function setTotalSupply(uint256 _amount) external {
        require(isPool[msg.sender], "TapETH: no pool");
        _totalSupply += _amount;
    }

    /**
     * @notice This function allows to rebase TapETH by increasing his total supply
     * from all stableSwap pools by the staking rewards and the swap fee.
     */
    function rebase() external {
        for (uint256 i = 0; i < pools.length; i++) {
            address _pool = pools[i];
            if (isPool[_pool]) {
                Ipool(_pool).rebase();
            }
        }
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @return the amount of shares that corresponds to `_tapETHAmount` protocol-controlled tapETH.
     */
    function getSharesByPooledEth(
        uint256 _tapETHAmount
    ) public view returns (uint256) {
        return (_tapETHAmount * _getTotalShares()) / _getTotalPooledEther();
    }

    /**
     * @return the amount of tapETH that corresponds to `_sharesAmount` token shares.
     */
    function getPooledEthByShares(
        uint256 _sharesAmount
    ) public view returns (uint256) {
        return (_sharesAmount * _getTotalPooledEther()) / (totalShares);
    }

    /**
     * @notice Moves `_sharesAmount` token shares from the caller's account to the `_recipient` account.
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
     */
    function transferShares(
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256) {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getPooledEthByShares(_sharesAmount);
        _emitTransferEvents(
            msg.sender,
            _recipient,
            tokensAmount,
            _sharesAmount
        );
        return tokensAmount;
    }

    /**
     * @notice Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account.
     *
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     *
     * Requirements:
     * - the caller must have allowance for `_sender`'s tokens of at least `getPooledEthByShares(_sharesAmount)`.
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
     */
    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256) {
        uint256 tokensAmount = getPooledEthByShares(_sharesAmount);
        _spendAllowance(_sender, msg.sender, tokensAmount);
        _transferShares(_sender, _recipient, _sharesAmount);
        _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }

    function mintShares(address _account, uint256 _sharesAmount) external {
        require(isPool[msg.sender], "TapETH: no pool");
        _mintShares(_account, _sharesAmount);
    }

    function burnShares(uint256 _sharesAmount) external {
        _burnShares(msg.sender, _sharesAmount);
    }

    function burnSharesFrom(address _account, uint256 _sharesAmount) external {
        _spendAllowance(_account, msg.sender, _sharesAmount);
        _burnShares(_account, _sharesAmount);
    }

    /**
     * @return the total amount (in wei) of tapETH controlled by the protocol.
     * @dev This is used for calculating tokens from shares and vice versa.
     */
    function _getTotalPooledEther() internal view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     */
    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        uint256 _sharesToTransfer = getSharesByPooledEth(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     *
     * Emits an `Approval` event.
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "TapETH: APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "TapETH: APPROVE_TO_ZERO_ADDR");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        uint256 currentAllowance = allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "TapETH: ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    /**
     * @return the total amount of shares in existence.
     */
    function _getTotalShares() internal view returns (uint256) {
        return totalShares;
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    /**
     * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
     */
    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) internal {
        require(_sender != address(0), "TapETH: zero address");
        require(_recipient != address(0), "TapETH: zero address");
        require(
            _recipient != address(this),
            "TapETH: TRANSFER_TO_tapETH_CONTRACT"
        );

        uint256 currentSenderShares = shares[_sender];
        require(
            _sharesAmount <= currentSenderShares,
            "TapETH: BALANCE_EXCEEDED"
        );

        shares[_sender] = currentSenderShares + _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    /**
     * @notice Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
     */
    function _mintShares(
        address _recipient,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), "TapETH: MINT_TO_ZERO_ADDR");

        totalShares += _sharesAmount;
        _totalSupply += _sharesAmount;
        newTotalShares = totalShares;
        shares[_recipient] += _sharesAmount;
    }

    /**
     * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
     */
    function _burnShares(
        address _account,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_account != address(0), "TapETH: BURN_FROM_ZERO_ADDR");

        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "TapETH: BALANCE_EXCEEDED");

        uint256 preRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

        totalShares -= _sharesAmount;
        newTotalShares = totalShares;
        shares[_account] -= _sharesAmount;

        uint256 postRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

        emit SharesBurnt(
            _account,
            preRebaseTokenAmount,
            postRebaseTokenAmount,
            _sharesAmount
        );
    }

    function _emitTransferEvents(
        address _from,
        address _to,
        uint _tokenAmount,
        uint256 _sharesAmount
    ) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }

    function _emitTransferAfterMintingShares(
        address _to,
        uint256 _sharesAmount
    ) internal {
        _emitTransferEvents(
            address(0),
            _to,
            getPooledEthByShares(_sharesAmount),
            _sharesAmount
        );
    }
}
