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

### acceptGovernance

```solidity
function acceptGovernance() external nonpayable
```



*Accept the govenance address.*


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
function claimable(address) external view returns (uint256)
```



*This is a mapping of index and total reward claimable.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimed

```solidity
function claimed(address) external view returns (uint256)
```



*This is a mapping of index and reward claimed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getClaimable

```solidity
function getClaimable() external view returns (uint256)
```



*Get claimable reward.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
function initialize(address _rewardToken, address _poolToken, uint256 _rewardRatePerWeek, contract IGaugeRewardController _rewardController) external nonpayable
```



*Initializes the GaugeController contract with the given parameters.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | The address for the reward token. |
| _poolToken | address | The address that receives yield farming rewards. |
| _rewardRatePerWeek | uint256 | undefined |
| _rewardController | contract IGaugeRewardController | undefined |

### lastCheckpoint

```solidity
function lastCheckpoint() external view returns (uint256)
```



*This is last checkpoint timestamp.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### pendingGovernance

```solidity
function pendingGovernance() external view returns (address)
```



*Pending governance address,*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### poolToken

```solidity
function poolToken() external view returns (address)
```



*Address for stable asset token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### proposeGovernance

```solidity
function proposeGovernance(address _governance) external nonpayable
```



*Propose the govenance address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _governance | address | Address of the new governance. |

### rewardController

```solidity
function rewardController() external view returns (contract IGaugeRewardController)
```



*Controller for reward weight calculation.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IGaugeRewardController | undefined |

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
event Checkpointed(address indexed poolAddress, uint256 totalAmount, uint256 timestamp)
```



*This event is emitted when a reward is checkpointed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolAddress `indexed` | address | is the pool address. |
| totalAmount  | uint256 | is the amount claimed. |
| timestamp  | uint256 | is timestamp of checkpoint. |

### Claimed

```solidity
event Claimed(address indexed poolAddress, uint256 amount)
```



*This event is emitted when a reward is claimed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
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

### GovernanceProposed

```solidity
event GovernanceProposed(address governance)
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

### RewardRateModified

```solidity
event RewardRateModified(uint256 rewardRatePerWeek)
```



*This event is emitted when the rewardRatePerWeek is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| rewardRatePerWeek  | uint256 | is the new value of the rewardRatePerWeek. |



