# VotingEscrow









## Methods

### CREATE_LOCK_TYPE

```solidity
function CREATE_LOCK_TYPE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### DEPOSIT_FOR_TYPE

```solidity
function DEPOSIT_FOR_TYPE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### INCREASE_LOCK_AMOUNT

```solidity
function INCREASE_LOCK_AMOUNT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### INCREASE_unlockTime

```solidity
function INCREASE_unlockTime() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MAXTIME

```solidity
function MAXTIME() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MULTIPLIER

```solidity
function MULTIPLIER() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### WEEK

```solidity
function WEEK() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### ZERO_ADDRESS

```solidity
function ZERO_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### admin

```solidity
function admin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### applySmartWalletChecker

```solidity
function applySmartWalletChecker() external nonpayable
```






### applyTransferOwnership

```solidity
function applyTransferOwnership() external nonpayable
```






### balanceOf

```solidity
function balanceOf(address addr, uint256 _t) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| _t | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### balanceOf

```solidity
function balanceOf(address addr) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### balanceOfAt

```solidity
function balanceOfAt(address addr, uint256 _block) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| _block | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### changeController

```solidity
function changeController(address _newController) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newController | address | undefined |

### checkpoint

```solidity
function checkpoint() external nonpayable
```






### commitSmartWalletChecker

```solidity
function commitSmartWalletChecker(address addr) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

### commitTransferOwnership

```solidity
function commitTransferOwnership(address addr) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

### controller

```solidity
function controller() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### createLock

```solidity
function createLock(uint256 _value, uint256 _unlockTime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _value | uint256 | undefined |
| _unlockTime | uint256 | undefined |

### decimals

```solidity
function decimals() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### delegate

```solidity
function delegate(address delegatee) external nonpayable
```



*Delegates votes from the sender to `delegatee`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegatee | address | undefined |

### delegateBySig

```solidity
function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*Delegates votes from signer to `delegatee`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegatee | address | undefined |
| nonce | uint256 | undefined |
| expiry | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### delegates

```solidity
function delegates(address account) external view returns (address)
```



*Returns the delegate that `account` has chosen.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### depositFor

```solidity
function depositFor(address _addr, uint256 _value) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _addr | address | undefined |
| _value | uint256 | undefined |

### epoch

```solidity
function epoch() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### futureAdmin

```solidity
function futureAdmin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### futureSmartWalletChecker

```solidity
function futureSmartWalletChecker() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getLastUserSlope

```solidity
function getLastUserSlope(address addr) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getPastTotalSupply

```solidity
function getPastTotalSupply(uint256 blockNumber) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getPastVotes

```solidity
function getPastVotes(address account, uint256 blockNumber) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| blockNumber | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getVotes

```solidity
function getVotes(address account) external view returns (uint256)
```



*Returns the current amount of votes that `account` has.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### increaseAmount

```solidity
function increaseAmount(uint256 _value) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _value | uint256 | undefined |

### increaseUnlockTime

```solidity
function increaseUnlockTime(uint256 _unlockTime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _unlockTime | uint256 | undefined |

### initialize

```solidity
function initialize(address tokenAddr, string _name, string _symbol, string _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddr | address | undefined |
| _name | string | undefined |
| _symbol | string | undefined |
| _version | string | undefined |

### locked

```solidity
function locked(address) external view returns (uint256 amount, uint256 end)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| end | uint256 | undefined |

### lockedEnd

```solidity
function lockedEnd(address _addr) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### name

```solidity
function name() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### pointHistory

```solidity
function pointHistory(uint256) external view returns (uint256 bias, uint256 slope, uint256 ts, uint256 blk)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| bias | uint256 | undefined |
| slope | uint256 | undefined |
| ts | uint256 | undefined |
| blk | uint256 | undefined |

### slopeChanges

```solidity
function slopeChanges(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### smartWalletChecker

```solidity
function smartWalletChecker() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### supply

```solidity
function supply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### token

```solidity
function token() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupply

```solidity
function totalSupply(uint256 t) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| t | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupplyAt

```solidity
function totalSupplyAt(uint256 _block) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _block | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfersEnabled

```solidity
function transfersEnabled() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### userPointEpoch

```solidity
function userPointEpoch(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### userPointHistory

```solidity
function userPointHistory(address, uint256) external view returns (uint256 bias, uint256 slope, uint256 ts, uint256 blk)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| bias | uint256 | undefined |
| slope | uint256 | undefined |
| ts | uint256 | undefined |
| blk | uint256 | undefined |

### userPointHistoryTs

```solidity
function userPointHistoryTs(address _addr, uint256 _idx) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _addr | address | undefined |
| _idx | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### version

```solidity
function version() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### withdraw

```solidity
function withdraw() external nonpayable
```








## Events

### ApplyOwnership

```solidity
event ApplyOwnership(address admin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| admin  | address | undefined |

### CommitOwnership

```solidity
event CommitOwnership(address admin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| admin  | address | undefined |

### DelegateChanged

```solidity
event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate)
```



*Emitted when an account changes their delegate.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegator `indexed` | address | undefined |
| fromDelegate `indexed` | address | undefined |
| toDelegate `indexed` | address | undefined |

### DelegateVotesChanged

```solidity
event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance)
```



*Emitted when a token transfer or delegate change results in changes to a delegate&#39;s number of votes.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegate `indexed` | address | undefined |
| previousBalance  | uint256 | undefined |
| newBalance  | uint256 | undefined |

### Deposit

```solidity
event Deposit(address indexed provider, uint256 value, uint256 indexed locktime, uint256 type_, uint256 ts)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| value  | uint256 | undefined |
| locktime `indexed` | uint256 | undefined |
| type_  | uint256 | undefined |
| ts  | uint256 | undefined |

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### Supply

```solidity
event Supply(uint256 prevSupply, uint256 supply)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| prevSupply  | uint256 | undefined |
| supply  | uint256 | undefined |

### Withdraw

```solidity
event Withdraw(address indexed provider, uint256 value, uint256 ts)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| value  | uint256 | undefined |
| ts  | uint256 | undefined |



