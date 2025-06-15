// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/ILPToken.sol";

error InsufficientAllowance(uint256 currentAllowance, uint256 amount);
error InsufficientBalance(uint256 currentBalance, uint256 amount);

/**
 * @title Interest-bearing ERC20-like token for Tapio protocol
 * @author Nuts Finance Developer
 * @notice ERC20 token minted by the StableSwap pools.
 * @dev LPToken is ERC20 rebase token minted by StableSwap pools for liquidity providers.
 * LPToken balances are dynamic and represent the holder's share in the total amount
 * of lpToken controlled by the protocol. Account shares aren't normalized, so the
 * contract also stores the sum of all shares to calculate each account's token balance
 * which equals to:
 *
 *   shares[account] * _totalSupply / _totalShares
 * where the _totalSupply is the total supply of lpToken controlled by the protocol.
 */
contract LPToken is Initializable, OwnableUpgradeable, ILPToken {
    /**
     * @dev Constant value representing an infinite allowance.
     */
    uint256 internal constant INFINITE_ALLOWANCE = ~uint256(0);

    /**
     * @dev Constant value representing the denominator for the buffer rate.
     */
    uint256 public constant BUFFER_DENOMINATOR = 10 ** 10;

    /**
     * @dev Constant value representing the number of dead shares.
     */
    uint256 public constant NUMBER_OF_DEAD_SHARES = 1000;

    /**
     * @dev The total amount of shares.
     */
    uint256 public totalShares;

    /**
     * @dev The total supply of lpToken
     */
    uint256 public totalSupply;

    /**
     * @dev The total amount of rewards
     */
    uint256 public totalRewards;

    /**
     * @dev The mapping of account shares.
     */
    mapping(address => uint256) public shares;

    /**
     * @dev The mapping of account allowances.
     */
    mapping(address => mapping(address => uint256)) private allowances;

    /**
     * @dev The buffer rate.
     */
    uint256 public bufferPercent;

    /**
     * @dev The buffer amount.
     */
    uint256 public bufferAmount;

    /**
     * @dev The token name.
     */
    string internal tokenName;

    /**
     * @dev The token symbol.
     */
    string internal tokenSymbol;

    /**
     * @dev The bad debt of the buffer.
     */
    uint256 public bufferBadDebt;

    /**
     * @dev The address of SPA pool.
     */
    address public pool;

    /**
     * @notice Emitted when shares are transferred.
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    /**
     * @notice Emitted when rewards are minted.
     */
    event RewardsMinted(uint256 amount, uint256 actualAmount);

    /**
     * @notice Emitted when the buffer rate is set.
     */
    event SetBufferPercent(uint256);

    /**
     * @notice Emitted when the buffer is increased.
     */
    event BufferIncreased(uint256, uint256);

    /**
     * @notice Emitted when the buffer is decreased.
     */
    event BufferDecreased(uint256, uint256);

    /**
     * @notice Emitted when Buffer is withdrawn to Treasury
     */
    event BufferWithdrawn(address indexed to, uint256 amount, uint256 bufferLeft);

    /**
     * @notice Emitted when there is negative rebase.
     */
    event NegativelyRebased(uint256, uint256);

    /**
     * @notice Emitted when the symbol is modified.
     */
    event SymbolModified(string);

    /// @notice Error thrown when the allowance is below zero.
    error AllowanceBelowZero();

    /// @notice Error thrown when array index is out of range.
    error OutOfRange();

    /// @notice Error thrown when the pool is not the caller.
    error NoPool();

    /// @notice Error thrown when the amount is invalid.
    error InvalidAmount();

    /// @notice Error thrown when the buffer is insufficient.
    error InsufficientBuffer();

    /// @notice Error thrown when the sender's address is zero.
    error ApproveFromZeroAddr();

    /// @notice Error thrown when the recipient's address is zero.
    error ApproveToZeroAddr();

    /// @notice Error thrown when the address is zero.
    error ZeroAddress();

    /// @notice Error thrown when transferring to the lpToken contract.
    error TransferToLPTokenContract();

    /// @notice Error thrown when minting to the zero address.
    error MintToZeroAddr();

    /// @notice Error thrown when burning from the zero address.
    error BurnFromZeroAddr();

    /// @notice Error thrown when the supply is insufficient.
    error InsufficientSupply();

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _buffer,
        address _keeper,
        address _pool
    )
        public
        initializer
    {
        require(_buffer < BUFFER_DENOMINATOR, OutOfRange());
        tokenName = _name;
        tokenSymbol = _symbol;
        pool = _pool;
        bufferPercent = _buffer;

        __Ownable_init(_keeper);
        emit SetBufferPercent(_buffer);
    }

    /**
     * @notice Moves `_sharesAmount` token shares from the caller's account to the `_recipient` account.
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     */
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256) {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getPeggedTokenByShares(_sharesAmount);
        _emitTransferEvents(msg.sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }

    /**
     * @notice Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account.
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens.
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     *
     * Requirements:
     * - the caller must have allowance for `_sender`'s tokens of at least `getPeggedTokenByShares(_sharesAmount)`.
     */
    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    )
        external
        returns (uint256)
    {
        uint256 tokensAmount = getPeggedTokenByShares(_sharesAmount);
        _spendAllowance(_sender, msg.sender, tokensAmount);
        _transferShares(_sender, _recipient, _sharesAmount);
        _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }

    /**
     * @dev Mints shares for the `_account` and transfers them to the `_account`.
     */
    function mintShares(address _account, uint256 _tokenAmount) external {
        require(msg.sender == pool, NoPool());
        _mintShares(_account, _tokenAmount);
    }

    /**
     * @dev Burns shares from the `_account`.
     */
    function burnShares(uint256 _tokenAmount) external {
        _burnShares(msg.sender, _tokenAmount);
    }

    /**
     * @dev Burns shares from the `_account`.
     */
    function burnSharesFrom(address _account, uint256 _tokenAmount) external {
        _spendAllowance(_account, msg.sender, _tokenAmount);
        _burnShares(_account, _tokenAmount);
    }

    /**
     * @notice Moves `_amount` tokens from the caller's account to the `_recipient`account.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * @return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     */
    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * @return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     * @dev The `_amount` argument is the amount of tokens, not shares.
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        _spendAllowance(_sender, msg.sender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    // solhint-disable max-line-length
    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender] += _addedValue);
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
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, AllowanceBelowZero());
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }
    // solhint-enable max-line-length

    /**
     * @notice This function is called by the keeper to set the buffer rate.
     */
    function setBuffer(uint256 _buffer) external onlyOwner {
        require(_buffer < BUFFER_DENOMINATOR, OutOfRange());
        bufferPercent = _buffer;
        emit SetBufferPercent(_buffer);
    }

    /**
     * @notice This function is called by the keeper to set the token symbol.
     */
    function setSymbol(string memory _symbol) external onlyOwner {
        tokenSymbol = _symbol;
        emit SymbolModified(_symbol);
    }

    /**
     * @notice This function is called only by a stableSwap pool to increase
     * the total supply of LPToken by the staking rewards and the swap fee.
     */
    function addTotalSupply(uint256 _amount) external {
        require(msg.sender == pool, NoPool());
        require(_amount != 0, InvalidAmount());

        if (bufferBadDebt >= _amount) {
            bufferBadDebt -= _amount;
            bufferAmount += _amount;
            emit BufferIncreased(_amount, bufferAmount);
            return;
        }

        uint256 prevAmount = _amount;
        uint256 prevBufferBadDebt = bufferBadDebt;
        _amount = _amount - bufferBadDebt;
        bufferAmount += bufferBadDebt;
        bufferBadDebt = 0;

        uint256 _deltaBuffer = (bufferPercent * _amount) / BUFFER_DENOMINATOR;
        uint256 actualAmount = _amount - _deltaBuffer;

        totalSupply += actualAmount;
        totalRewards += actualAmount;
        bufferAmount += _deltaBuffer;

        emit BufferIncreased(_deltaBuffer + prevBufferBadDebt, bufferAmount);
        emit RewardsMinted(prevAmount, actualAmount);
    }

    /**
     * @notice This function is called only by a stableSwap pool to decrease
     * the total supply of LPToken by lost amount.
     * @param _amount The amount of lost tokens.
     * @param isBuffer The flag to indicate whether to use the buffer or not.
     * @param withDebt The flag to indicate whether to add the lost amount to the buffer bad debt or not.
     */
    function removeTotalSupply(uint256 _amount, bool isBuffer, bool withDebt) external {
        require(msg.sender == pool, NoPool());
        require(_amount != 0, InvalidAmount());

        if (isBuffer) {
            require(_amount <= bufferAmount, InsufficientBuffer());
            bufferAmount -= _amount;
            if (withDebt) {
                bufferBadDebt += _amount;
            }
            emit BufferDecreased(_amount, bufferAmount);
        } else {
            require(_amount <= totalSupply, InsufficientSupply());
            totalSupply -= _amount;
            emit NegativelyRebased(_amount, totalSupply);
        }
    }

    /**
     * @notice This function is called only by a stableSwap pool to increase
     * the total supply of LPToken
     */
    function addBuffer(uint256 _amount) external {
        require(msg.sender == pool, NoPool());
        require(_amount != 0, InvalidAmount());

        bufferAmount += _amount;
        emit BufferIncreased(_amount, bufferAmount);
    }

    /**
     * @notice Withdraw `_amount` from Buffer and mint LP shares to `_to`
     * Callable only by Governor via Keeper (which is owner)
     * @param _to Recipient address that will receive newly–minted shares
     * @param _amount Token amount to withdraw
     */
    function withdrawBuffer(address _to, uint256 _amount) external onlyOwner {
        require(_amount != 0, InvalidAmount());
        require(_amount <= bufferAmount, InsufficientBuffer());
        require(_to != address(0), ZeroAddress());

        bufferAmount -= _amount;
        _mintShares(_to, _amount);
        emit BufferWithdrawn(_to, _amount, bufferAmount);
    }

    /**
     * @dev Returns the name of the token.
     * @return the name of the token.
     */
    function name() external view returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Returns the symbol of the token.
     * @return the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
     * total lpToken controlled by the protocol. See `sharesOf`.
     * @return the amount of tokens owned by the `_account`.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return getPeggedTokenByShares(_sharesOf(_account));
    }

    /**
     * @dev This value changes when `approve` or `transferFrom` is called.
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @dev Returns the decimals of the token.
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @return the amount of lpToken that corresponds to `_sharesAmount` token shares.
     */
    function getPeggedTokenByShares(uint256 _sharesAmount) public view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        } else {
            return (_sharesAmount * totalSupply) / totalShares;
        }
    }

    /**
     * @return the amount of shares that corresponds to `_lpTokenAmount` protocol-controlled lpToken.
     */
    function getSharesByPeggedToken(uint256 _lpTokenAmount) public view returns (uint256) {
        if (totalSupply == 0) {
            return 0;
        } else {
            return (_lpTokenAmount * totalShares) / totalSupply;
        }
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = getSharesByPeggedToken(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     *
     * Emits an `Approval` event.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), ApproveFromZeroAddr());
        require(_spender != address(0), ApproveToZeroAddr());

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
    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            if (currentAllowance < _amount) {
                revert InsufficientAllowance(currentAllowance, _amount);
            }

            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    /**
     * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
     */
    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), ZeroAddress());
        require(_recipient != address(0), ZeroAddress());
        require(_recipient != address(this), TransferToLPTokenContract());

        uint256 currentSenderShares = shares[_sender];

        if (_sharesAmount > currentSenderShares) {
            revert InsufficientBalance(currentSenderShares, _sharesAmount);
        }

        shares[_sender] -= _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    /**
     * @notice Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
     */
    function _mintShares(address _recipient, uint256 _tokenAmount) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), MintToZeroAddr());
        uint256 _sharesAmount;
        if (totalSupply != 0 && totalShares != 0) {
            _sharesAmount = getSharesByPeggedToken(_tokenAmount);
        } else {
            _sharesAmount = totalSupply + _tokenAmount - NUMBER_OF_DEAD_SHARES;
            shares[address(0)] = NUMBER_OF_DEAD_SHARES;
            totalShares += NUMBER_OF_DEAD_SHARES;
        }
        shares[_recipient] += _sharesAmount;
        totalShares += _sharesAmount;
        newTotalShares = totalShares;
        totalSupply += _tokenAmount;

        _emitTransferAfterMintingShares(_recipient, _sharesAmount);
    }

    /**
     * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
     */
    function _burnShares(address _account, uint256 _tokenAmount) internal returns (uint256 newTotalShares) {
        require(_account != address(0), BurnFromZeroAddr());

        uint256 _balance = getPeggedTokenByShares(_sharesOf(_account));
        if (_tokenAmount > _balance) {
            revert InsufficientBalance(_balance, _tokenAmount);
        }

        uint256 _sharesAmount = getSharesByPeggedToken(_tokenAmount);
        shares[_account] -= _sharesAmount;
        totalShares -= _sharesAmount;
        newTotalShares = totalShares;
        totalSupply -= _tokenAmount;

        _emitTransferAfterBurningShares(_account, _sharesAmount);
    }

    /**
     * @notice Emits Transfer and TransferShares events.
     */
    function _emitTransferEvents(address _from, address _to, uint256 _tokenAmount, uint256 _sharesAmount) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }

    /**
     * @notice Emits Transfer and TransferShares events after minting shares.
     */
    function _emitTransferAfterMintingShares(address _to, uint256 _sharesAmount) internal {
        _emitTransferEvents(address(0), _to, getPeggedTokenByShares(_sharesAmount), _sharesAmount);
    }

    /**
     * @notice Emits Transfer and TransferShares events after burning shares.
     */
    function _emitTransferAfterBurningShares(address _from, uint256 _sharesAmount) internal {
        _emitTransferEvents(_from, address(0), getPeggedTokenByShares(_sharesAmount), _sharesAmount);
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }
}
