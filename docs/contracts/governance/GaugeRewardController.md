# GaugeRewardController









## Methods

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

### WEIGHT_VOTE_DELAY

```solidity
function WEIGHT_VOTE_DELAY() external view returns (uint256)
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

### addGauge

```solidity
function addGauge(address addr, uint128 gaugeType, uint256 weight) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| gaugeType | uint128 | undefined |
| weight | uint256 | undefined |

### addGauge

```solidity
function addGauge(address addr, uint128 gaugeType) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| gaugeType | uint128 | undefined |

### addType

```solidity
function addType(string _name, uint256 weight) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | undefined |
| weight | uint256 | undefined |

### addType

```solidity
function addType(string _name) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | undefined |

### admin

```solidity
function admin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### applyTransferOwnership

```solidity
function applyTransferOwnership() external nonpayable
```






### changeGaugeWeight

```solidity
function changeGaugeWeight(address addr, uint256 weight) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| weight | uint256 | undefined |

### changeTypeWeight

```solidity
function changeTypeWeight(uint128 typeId, uint256 weight) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| typeId | uint128 | undefined |
| weight | uint256 | undefined |

### changesSum

```solidity
function changesSum(uint128, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### changesWeight

```solidity
function changesWeight(address, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### checkpoint

```solidity
function checkpoint() external nonpayable
```






### checkpointGauge

```solidity
function checkpointGauge(address addr) external nonpayable
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

### futureAdmin

```solidity
function futureAdmin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### gaugeRelativeWeight

```solidity
function gaugeRelativeWeight(address addr, uint256 time) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| time | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### gaugeRelativeWeight

```solidity
function gaugeRelativeWeight(address addr) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### gaugeRelativeWeightWrite

```solidity
function gaugeRelativeWeightWrite(address addr) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### gaugeRelativeWeightWrite

```solidity
function gaugeRelativeWeightWrite(address addr, uint256 time) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |
| time | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### gaugeTypeNames

```solidity
function gaugeTypeNames(uint128) external view returns (string)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### gaugeTypes

```solidity
function gaugeTypes(address _addr) external view returns (uint128)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

### gaugeTypes_

```solidity
function gaugeTypes_(address) external view returns (uint128)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

### gauges

```solidity
function gauges(uint256) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getGauge

```solidity
function getGauge(uint128 index) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint128 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getGaugeWeight

```solidity
function getGaugeWeight(address addr) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTotalWeight

```solidity
function getTotalWeight() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTypeWeight

```solidity
function getTypeWeight(uint128 typeId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| typeId | uint128 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getWeightsSumPerType

```solidity
function getWeightsSumPerType(uint128 typeId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| typeId | uint128 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initialize

```solidity
function initialize(address _token, address _votingEscrow) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _token | address | undefined |
| _votingEscrow | address | undefined |

### lastUserVote

```solidity
function lastUserVote(address, address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### nGaugeTypes

```solidity
function nGaugeTypes() external view returns (uint128)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

### nGauges

```solidity
function nGauges() external view returns (uint128)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

### pointsSum

```solidity
function pointsSum(uint128, uint256) external view returns (uint256 bias, uint256 slope)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| bias | uint256 | undefined |
| slope | uint256 | undefined |

### pointsTotal

```solidity
function pointsTotal(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### pointsTypeWeight

```solidity
function pointsTypeWeight(uint128, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### pointsWeight

```solidity
function pointsWeight(address, uint256) external view returns (uint256 bias, uint256 slope)
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

### timeSum

```solidity
function timeSum(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### timeTotal

```solidity
function timeTotal() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### timeTypeWeight

```solidity
function timeTypeWeight(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### timeWeight

```solidity
function timeWeight(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### token

```solidity
function token() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### voteForGaugeWeights

```solidity
function voteForGaugeWeights(address _gaugeAddr, uint256 _userWeight) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _gaugeAddr | address | undefined |
| _userWeight | uint256 | undefined |

### voteUserPower

```solidity
function voteUserPower(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### voteUserSlopes

```solidity
function voteUserSlopes(address, address) external view returns (uint256 slope, uint256 power, uint256 end)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| slope | uint256 | undefined |
| power | uint256 | undefined |
| end | uint256 | undefined |

### votingEscrow

```solidity
function votingEscrow() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |



## Events

### AddType

```solidity
event AddType(string name, uint128 typeId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name  | string | undefined |
| typeId  | uint128 | undefined |

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

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### NewGauge

```solidity
event NewGauge(address addr, uint128 gaugeType, uint256 weight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr  | address | undefined |
| gaugeType  | uint128 | undefined |
| weight  | uint256 | undefined |

### NewGaugeWeight

```solidity
event NewGaugeWeight(address gaugeAddress, uint256 time, uint256 weight, uint256 totalWeight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| gaugeAddress  | address | undefined |
| time  | uint256 | undefined |
| weight  | uint256 | undefined |
| totalWeight  | uint256 | undefined |

### NewTypeWeight

```solidity
event NewTypeWeight(uint128 typeId, uint256 time, uint256 weight, uint256 totalWeight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| typeId  | uint128 | undefined |
| time  | uint256 | undefined |
| weight  | uint256 | undefined |
| totalWeight  | uint256 | undefined |

### VoteForGauge

```solidity
event VoteForGauge(uint256 time, address user, address gaugeAddr, uint256 weight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| time  | uint256 | undefined |
| user  | address | undefined |
| gaugeAddr  | address | undefined |
| weight  | uint256 | undefined |



