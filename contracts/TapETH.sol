// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./interfaces/ITapETH.sol";

interface Ipool {
    function rebase() external returns (uint256);
}

contract TapETH is ITapETH {
    uint256 internal constant INFINITE_ALLOWANCE = ~uint256(0);

    uint256 private totalShares;
    uint256 private _totalSupply;
    address public governance;
    address public pendingGovernance;
    mapping(address => uint256) private shares;

    mapping(address => bool) public isPool;
    address[] public pools;
    mapping(address => mapping(address => uint256)) private allowances;

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
        require(msg.sender == governance, "not governance");
        pendingGovernance = _governance;
        emit GovernanceProposed(_governance);
    }

    function acceptGovernance() public {
        require(msg.sender == pendingGovernance, "not pending governance");
        governance = pendingGovernance;
        pendingGovernance = address(0);
        emit GovernanceModified(governance);
    }

    function addMinter(address _pool) public {
        require(msg.sender == governance, "not governance");
        require(!isPool[_pool], "minter exists");
        isPool[_pool] = true;
        pools.push(_pool);
        emit PoolAdded(_pool);
    }

    function removeMinter(address _pool) public {
        require(msg.sender == governance, "not governance");
        require(isPool[_pool], "minter exists");
        isPool[_pool] = false;
        emit PoolRemoved(_pool);
    }

    function name() public view virtual returns (string memory) {
        return "TapETH";
    }

    function symbol() public view virtual returns (string memory) {
        return "TapETH";
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getTotalPooledEther() external view returns (uint256) {
        return _getTotalPooledEther();
    }

    function balanceOf(address _account) external view returns (uint256) {
        return getPooledEthByShares(_sharesOf(_account));
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        _spendAllowance(_sender, msg.sender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

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

    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }

    function setTotalSupply(uint256 _amount) external {
        require(isPool[msg.sender], "not minter");
        _totalSupply += _amount;
    }

    function rebase() external {
        for (uint256 i = 0; i < pools.length; i++) {
            address _pool = pools[i];
            if (isPool[_pool]) {
                Ipool(_pool).rebase();
            }
        }
    }

    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    function getSharesByPooledEth(
        uint256 _ethAmount
    ) public view returns (uint256) {
        return (_ethAmount * _getTotalShares()) / _getTotalPooledEther();
    }

    function getPooledEthByShares(
        uint256 _sharesAmount
    ) public view returns (uint256) {
        return (_sharesAmount * _getTotalPooledEther()) / (totalShares);
    }

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
        require(isPool[msg.sender], "not minter");
        _mintShares(_account, _sharesAmount);
    }

    function burnShares(uint256 _sharesAmount) external {
        require(isPool[msg.sender], "not minter");
        _burnShares(msg.sender, _sharesAmount);
    }

    function burnSharesFrom(address _account, uint256 _sharesAmount) external {
        require(isPool[msg.sender], "not minter");
        _spendAllowance(_account, msg.sender, _sharesAmount);
        _burnShares(_account, _sharesAmount);
    }

    function _getTotalPooledEther() internal view returns (uint256) {
        return _totalSupply;
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        uint256 _sharesToTransfer = getSharesByPooledEth(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDR");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        uint256 currentAllowance = allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    function _getTotalShares() internal view returns (uint256) {
        return totalShares;
    }

    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) internal {
        require(_sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(_recipient != address(0), "TRANSFER_TO_ZERO_ADDR");
        require(_recipient != address(this), "TRANSFER_TO_STETH_CONTRACT");

        uint256 currentSenderShares = shares[_sender];
        require(_sharesAmount <= currentSenderShares, "BALANCE_EXCEEDED");

        shares[_sender] = currentSenderShares + _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    function _mintShares(
        address _recipient,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), "MINT_TO_ZERO_ADDR");

        totalShares += _sharesAmount;
        newTotalShares = totalShares;
        shares[_recipient] += _sharesAmount;
    }

    function _burnShares(
        address _account,
        uint256 _sharesAmount
    ) internal returns (uint256 newTotalShares) {
        require(_account != address(0), "BURN_FROM_ZERO_ADDR");

        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BALANCE_EXCEEDED");

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
