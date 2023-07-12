# GaugeController

*Nuts Finance Developer*

> GaugeController

The GaugeController provides a way to distribute reward

*The GaugeController contract allows reward distribution*

## Methods

### WEEK

```solidity
function WEEK() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addPool

```solidity
function addPool(address _poolAddress) external nonpayable
```



*Add a new pool.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _poolAddress | address | The pool address to add. |

### checkpoint

```solidity
function checkpoint() external nonpayable
```



*Calculate new reward.*


### claim

```solidity
function claim() external nonpayable
```



*Claim reward.*


### claimable

```solidity
function claimable(uint256) external view returns (uint256)
```



*This is a mapping of index and total reward claimable.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimed

```solidity
function claimed(uint256) external view returns (uint256)
```



*This is a mapping of index and reward claimed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### disablePool

```solidity
function disablePool(uint256 _poolIndex) external nonpayable
```



*Disable a pool.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _poolIndex | uint256 | The pool index to disable. |

### enablePool

```solidity
function enablePool(uint256 _poolIndex) external nonpayable
```



*Enable a pool.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _poolIndex | uint256 | The pool index to enable. |

### governance

```solidity
function governance() external view returns (address)
```



*This is the account that has governance control over the GaugeController contract.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### initialize

```solidity
function initialize(address _rewardToken, address _poolToken, uint256 _rewardRatePerWeek) external nonpayable
```



*Initializes the GaugeController contract with the given parameters.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | The address for the reward token. |
| _poolToken | address | The address that receives yield farming rewards. |
| _rewardRatePerWeek | uint256 | undefined |

### lastCheckpoint

```solidity
function lastCheckpoint() external view returns (uint256)
```



*This is last checkpoint timestamp.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### poolActivated

```solidity
function poolActivated(uint256) external view returns (bool)
```



*This is a mapping of index and pool activated.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### poolAddressToIndex

```solidity
function poolAddressToIndex(address) external view returns (uint256)
```



*This is a mapping of index and pool address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### poolIndexToAddress

```solidity
function poolIndexToAddress(uint256) external view returns (address)
```



*This is a mapping of index and pool address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### poolSize

```solidity
function poolSize() external view returns (uint256)
```



*This is the total count of pool.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### poolToken

```solidity
function poolToken() external view returns (address)
```



*Address for stable asset token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### poolWeight

```solidity
function poolWeight(uint256) external view returns (uint256)
```



*This is a mapping of index and pool weight.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardRatePerWeek

```solidity
function rewardRatePerWeek() external view returns (uint256)
```



*This is reward rate per week.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardToken

```solidity
function rewardToken() external view returns (address)
```



*Address for the reward token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### setGovernance

```solidity
function setGovernance(address _governance) external nonpayable
```



*Updates the govenance address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _governance | address | The new governance address. |

### updatePoolWeight

```solidity
function updatePoolWeight(uint256 _poolIndex, uint256 weight) external nonpayable
```



*Disable a pool.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _poolIndex | uint256 | The pool index to modify weight. |
| weight | uint256 | The pool weight. |

### updateRewardRate

```solidity
function updateRewardRate(uint256 _rewardRatePerWeek) external nonpayable
```



*Updates the reward rate.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardRatePerWeek | uint256 | The new reward rate. |



## Events

### Checkpointed

```solidity
event Checkpointed(uint256 indexed poolIndex, address indexed poolAddress, uint256 totalAmount, uint256 timestamp)
```



*This event is emitted when a reward is checkpointed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the pool index. |
| poolAddress `indexed` | address | is the pool address. |
| totalAmount  | uint256 | is the amount claimed. |
| timestamp  | uint256 | is timestamp of checkpoint. |

### Claimed

```solidity
event Claimed(uint256 indexed poolIndex, address indexed poolAddress, uint256 amount)
```



*This event is emitted when a reward is claimed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the pool index. |
| poolAddress `indexed` | address | is the pool address. |
| amount  | uint256 | is the amount claimed. |

### GovernanceModified

```solidity
event GovernanceModified(address governance)
```



*This event is emitted when the governance is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| governance  | address | is the new value of the governance. |

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### PoolAdded

```solidity
event PoolAdded(uint256 indexed poolIndex, address indexed poolAddress)
```



*This event is emitted when a new pool is added.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the new pool index. |
| poolAddress `indexed` | address | is the new pool address. |

### PoolDisabled

```solidity
event PoolDisabled(uint256 indexed poolIndex, address indexed poolAddress)
```



*This event is emitted when a pool is disabled.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the pool index. |
| poolAddress `indexed` | address | is the pool address. |

### PoolEnabled

```solidity
event PoolEnabled(uint256 indexed poolIndex, address indexed poolAddress)
```



*This event is emitted when a pool is enabled.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the pool index. |
| poolAddress `indexed` | address | is the pool address. |

### PoolWeightUpdated

```solidity
event PoolWeightUpdated(uint256 indexed poolIndex, address indexed poolAddress, uint256 weight)
```



*This event is emitted when a pool weight is updated.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolIndex `indexed` | uint256 | is the pool index. |
| poolAddress `indexed` | address | is the pool address. |
| weight  | uint256 | is the pool weight. |

### RewardRateModified

```solidity
event RewardRateModified(uint256 rewardRatePerWeek)
```



*This event is emitted when the rewardRatePerWeek is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| rewardRatePerWeek  | uint256 | is the new value of the rewardRatePerWeek. |



