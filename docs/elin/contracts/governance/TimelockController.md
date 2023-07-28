# TimelockController







*Contract module which acts as a timelocked controller. When set as the owner of an `Ownable` smart contract, it enforces a timelock on all `onlyOwner` maintenance operations. This gives time for users of the controlled contract to exit before a potentially dangerous maintenance operation is applied. By default, this contract is self administered, meaning administration tasks have to go through the timelock process. The proposer (resp executor) role is in charge of proposing (resp executing) operations. A common use case is to position this {TimelockController} as the owner of a smart contract, with a multisig or a DAO as the sole proposer. _Available since v3.3._*

## Methods

### CANCELLER_ROLE

```solidity
function CANCELLER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### DEFAULT_ADMIN_ROLE

```solidity
function DEFAULT_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### EXECUTOR_ROLE

```solidity
function EXECUTOR_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### PROPOSER_ROLE

```solidity
function PROPOSER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### TIMELOCK_ADMIN_ROLE

```solidity
function TIMELOCK_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### cancel

```solidity
function cancel(bytes32 id) external nonpayable
```



*Cancel an operation. Requirements: - the caller must have the &#39;canceller&#39; role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

### execute

```solidity
function execute(address target, uint256 value, bytes payload, bytes32 predecessor, bytes32 salt) external payable
```



*Execute an (ready) operation containing a single transaction. Emits a {CallExecuted} event. Requirements: - the caller must have the &#39;executor&#39; role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| target | address | undefined |
| value | uint256 | undefined |
| payload | bytes | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |

### executeBatch

```solidity
function executeBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) external payable
```



*Execute an (ready) operation containing a batch of transactions. Emits one {CallExecuted} event per transaction in the batch. Requirements: - the caller must have the &#39;executor&#39; role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| payloads | bytes[] | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |

### getMinDelay

```solidity
function getMinDelay() external view returns (uint256 duration)
```



*Returns the minimum delay for an operation to become valid. This value can be changed by executing an operation that calls `updateDelay`.*


#### Returns

| Name | Type | Description |
|---|---|---|
| duration | uint256 | undefined |

### getRoleAdmin

```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32)
```



*Returns the admin role that controls `role`. See {grantRole} and {revokeRole}. To change a role&#39;s admin, use {_setRoleAdmin}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### getTimestamp

```solidity
function getTimestamp(bytes32 id) external view returns (uint256 timestamp)
```



*Returns the timestamp at with an operation becomes ready (0 for unset operations, 1 for done operations).*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| timestamp | uint256 | undefined |

### grantRole

```solidity
function grantRole(bytes32 role, address account) external nonpayable
```



*Grants `role` to `account`. If `account` had not been already granted `role`, emits a {RoleGranted} event. Requirements: - the caller must have ``role``&#39;s admin role. May emit a {RoleGranted} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### hasRole

```solidity
function hasRole(bytes32 role, address account) external view returns (bool)
```



*Returns `true` if `account` has been granted `role`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### hashOperation

```solidity
function hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) external pure returns (bytes32 hash)
```



*Returns the identifier of an operation containing a single transaction.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| target | address | undefined |
| value | uint256 | undefined |
| data | bytes | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| hash | bytes32 | undefined |

### hashOperationBatch

```solidity
function hashOperationBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) external pure returns (bytes32 hash)
```



*Returns the identifier of an operation containing a batch of transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| payloads | bytes[] | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| hash | bytes32 | undefined |

### isOperation

```solidity
function isOperation(bytes32 id) external view returns (bool registered)
```



*Returns whether an id correspond to a registered operation. This includes both Pending, Ready and Done operations.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| registered | bool | undefined |

### isOperationDone

```solidity
function isOperationDone(bytes32 id) external view returns (bool done)
```



*Returns whether an operation is done or not.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| done | bool | undefined |

### isOperationPending

```solidity
function isOperationPending(bytes32 id) external view returns (bool pending)
```



*Returns whether an operation is pending or not.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| pending | bool | undefined |

### isOperationReady

```solidity
function isOperationReady(bytes32 id) external view returns (bool ready)
```



*Returns whether an operation is ready or not.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| ready | bool | undefined |

### onERC1155BatchReceived

```solidity
function onERC1155BatchReceived(address, address, uint256[], uint256[], bytes) external nonpayable returns (bytes4)
```



*See {IERC1155Receiver-onERC1155BatchReceived}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |
| _2 | uint256[] | undefined |
| _3 | uint256[] | undefined |
| _4 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

### onERC1155Received

```solidity
function onERC1155Received(address, address, uint256, uint256, bytes) external nonpayable returns (bytes4)
```



*See {IERC1155Receiver-onERC1155Received}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |
| _2 | uint256 | undefined |
| _3 | uint256 | undefined |
| _4 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external nonpayable returns (bytes4)
```



*See {IERC721Receiver-onERC721Received}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |
| _2 | uint256 | undefined |
| _3 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

### renounceRole

```solidity
function renounceRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from the calling account. Roles are often managed via {grantRole} and {revokeRole}: this function&#39;s purpose is to provide a mechanism for accounts to lose their privileges if they are compromised (such as when a trusted device is misplaced). If the calling account had been revoked `role`, emits a {RoleRevoked} event. Requirements: - the caller must be `account`. May emit a {RoleRevoked} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### revokeRole

```solidity
function revokeRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from `account`. If `account` had been granted `role`, emits a {RoleRevoked} event. Requirements: - the caller must have ``role``&#39;s admin role. May emit a {RoleRevoked} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### schedule

```solidity
function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay) external nonpayable
```



*Schedule an operation containing a single transaction. Emits a {CallScheduled} event. Requirements: - the caller must have the &#39;proposer&#39; role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| target | address | undefined |
| value | uint256 | undefined |
| data | bytes | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |
| delay | uint256 | undefined |

### scheduleBatch

```solidity
function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) external nonpayable
```



*Schedule an operation containing a batch of transactions. Emits one {CallScheduled} event per transaction in the batch. Requirements: - the caller must have the &#39;proposer&#39; role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| payloads | bytes[] | undefined |
| predecessor | bytes32 | undefined |
| salt | bytes32 | undefined |
| delay | uint256 | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```



*See {IERC165-supportsInterface}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### updateDelay

```solidity
function updateDelay(uint256 newDelay) external nonpayable
```



*Changes the minimum timelock duration for future operations. Emits a {MinDelayChange} event. Requirements: - the caller must be the timelock itself. This can only be achieved by scheduling and later executing an operation where the timelock is the target and the data is the ABI-encoded call to this function.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newDelay | uint256 | undefined |



## Events

### CallExecuted

```solidity
event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)
```



*Emitted when a call is performed as part of operation `id`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | bytes32 | undefined |
| index `indexed` | uint256 | undefined |
| target  | address | undefined |
| value  | uint256 | undefined |
| data  | bytes | undefined |

### CallScheduled

```solidity
event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
```



*Emitted when a call is scheduled as part of operation `id`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | bytes32 | undefined |
| index `indexed` | uint256 | undefined |
| target  | address | undefined |
| value  | uint256 | undefined |
| data  | bytes | undefined |
| predecessor  | bytes32 | undefined |
| delay  | uint256 | undefined |

### Cancelled

```solidity
event Cancelled(bytes32 indexed id)
```



*Emitted when operation `id` is cancelled.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | bytes32 | undefined |

### MinDelayChange

```solidity
event MinDelayChange(uint256 oldDuration, uint256 newDuration)
```



*Emitted when the minimum delay for future operations is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| oldDuration  | uint256 | undefined |
| newDuration  | uint256 | undefined |

### RoleAdminChanged

```solidity
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
```



*Emitted when `newAdminRole` is set as ``role``&#39;s admin role, replacing `previousAdminRole` `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite {RoleAdminChanged} not being emitted signaling this. _Available since v3.1._*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| previousAdminRole `indexed` | bytes32 | undefined |
| newAdminRole `indexed` | bytes32 | undefined |

### RoleGranted

```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
```



*Emitted when `account` is granted `role`. `sender` is the account that originated the contract call, an admin role bearer except when using {AccessControl-_setupRole}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |

### RoleRevoked

```solidity
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
```



*Emitted when `account` is revoked `role`. `sender` is the account that originated the contract call:   - if using `revokeRole`, it is the admin role bearer   - if using `renounceRole`, it is the role bearer (i.e. `account`)*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |



