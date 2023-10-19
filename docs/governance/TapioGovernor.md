# TapioGovernor









## Methods

### BALLOT_TYPEHASH

```solidity
function BALLOT_TYPEHASH() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### CLOCK_MODE

```solidity
function CLOCK_MODE() external view returns (string)
```



*Machine-readable description of the clock as specified in EIP-6372.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### COUNTING_MODE

```solidity
function COUNTING_MODE() external pure returns (string)
```

module:voting

*A description of the possible `support` values for {castVote} and the way these votes are counted, meant to be consumed by UIs to show correct vote options and interpret the results. The string is a URL-encoded sequence of key-value pairs that each describe one aspect, for example `support=bravo&amp;quorum=for,abstain`. There are 2 standard keys: `support` and `quorum`. - `support=bravo` refers to the vote options 0 = Against, 1 = For, 2 = Abstain, as in `GovernorBravo`. - `quorum=bravo` means that only For votes are counted towards quorum. - `quorum=for,abstain` means that both For and Abstain votes are counted towards quorum. If a counting module makes use of encoded `params`, it should  include this under a `params` key with a unique name that describes the behavior. For example: - `params=fractional` might refer to a scheme where votes are divided fractionally between for/against/abstain. - `params=erc721` might refer to a scheme where specific NFTs are delegated to vote. NOTE: The string can be decoded by the standard https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams[`URLSearchParams`] JavaScript class.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### EXTENDED_BALLOT_TYPEHASH

```solidity
function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### _proposalThreshold

```solidity
function _proposalThreshold() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### _votingDelay

```solidity
function _votingDelay() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### _votingPeriod

```solidity
function _votingPeriod() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### cancel

```solidity
function cancel(uint256 proposalId) external nonpayable
```



*Cancel a proposal with GovernorBravo logic.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

### cancel

```solidity
function cancel(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| calldatas | bytes[] | undefined |
| descriptionHash | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### castVote

```solidity
function castVote(uint256 proposalId, uint8 support) external nonpayable returns (uint256)
```



*See {IGovernor-castVote}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| support | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### castVoteBySig

```solidity
function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external nonpayable returns (uint256)
```



*See {IGovernor-castVoteBySig}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| support | uint8 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### castVoteWithReason

```solidity
function castVoteWithReason(uint256 proposalId, uint8 support, string reason) external nonpayable returns (uint256)
```



*See {IGovernor-castVoteWithReason}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| support | uint8 | undefined |
| reason | string | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### castVoteWithReasonAndParams

```solidity
function castVoteWithReasonAndParams(uint256 proposalId, uint8 support, string reason, bytes params) external nonpayable returns (uint256)
```



*See {IGovernor-castVoteWithReasonAndParams}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| support | uint8 | undefined |
| reason | string | undefined |
| params | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### castVoteWithReasonAndParamsBySig

```solidity
function castVoteWithReasonAndParamsBySig(uint256 proposalId, uint8 support, string reason, bytes params, uint8 v, bytes32 r, bytes32 s) external nonpayable returns (uint256)
```



*See {IGovernor-castVoteWithReasonAndParamsBySig}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| support | uint8 | undefined |
| reason | string | undefined |
| params | bytes | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### clock

```solidity
function clock() external view returns (uint48)
```



*Clock (as specified in EIP-6372) is set to match the token&#39;s clock. Fallback to block numbers if the token does not implement EIP-6372.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

### eip712Domain

```solidity
function eip712Domain() external view returns (bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions)
```



*See {EIP-5267}. _Available since v4.9._*


#### Returns

| Name | Type | Description |
|---|---|---|
| fields | bytes1 | undefined |
| name | string | undefined |
| version | string | undefined |
| chainId | uint256 | undefined |
| verifyingContract | address | undefined |
| salt | bytes32 | undefined |
| extensions | uint256[] | undefined |

### execute

```solidity
function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) external payable returns (uint256)
```



*See {IGovernor-execute}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| calldatas | bytes[] | undefined |
| descriptionHash | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### execute

```solidity
function execute(uint256 proposalId) external payable
```



*See {IGovernorCompatibilityBravo-execute}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

### getActions

```solidity
function getActions(uint256 proposalId) external view returns (address[] targets, uint256[] values, string[] signatures, bytes[] calldatas)
```



*See {IGovernorCompatibilityBravo-getActions}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| signatures | string[] | undefined |
| calldatas | bytes[] | undefined |

### getReceipt

```solidity
function getReceipt(uint256 proposalId, address voter) external view returns (struct IGovernorCompatibilityBravo.Receipt)
```



*See {IGovernorCompatibilityBravo-getReceipt}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| voter | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | IGovernorCompatibilityBravo.Receipt | undefined |

### getVotes

```solidity
function getVotes(address account, uint256 timepoint) external view returns (uint256)
```



*See {IGovernor-getVotes}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| timepoint | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getVotesWithParams

```solidity
function getVotesWithParams(address account, uint256 timepoint, bytes params) external view returns (uint256)
```



*See {IGovernor-getVotesWithParams}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| timepoint | uint256 | undefined |
| params | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### governance

```solidity
function governance() external view returns (address)
```



*This is the account that has governance control over the TapioGovernor contract.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### hasVoted

```solidity
function hasVoted(uint256 proposalId, address account) external view returns (bool)
```



*See {IGovernor-hasVoted}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### hashProposal

```solidity
function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) external pure returns (uint256)
```



*See {IGovernor-hashProposal}. The proposal id is produced by hashing the ABI encoded `targets` array, the `values` array, the `calldatas` array and the descriptionHash (bytes32 which itself is the keccak256 hash of the description string). This proposal id can be produced from the proposal data which is part of the {ProposalCreated} event. It can even be computed in advance, before the proposal is submitted. Note that the chainId and the governor address are not part of the proposal id computation. Consequently, the same proposal (with same operation and same description) will have the same id if submitted on multiple governors across multiple networks. This also means that in order to execute the same operation twice (on the same governor) the proposer will have to change the description in order to avoid proposal id conflicts.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| calldatas | bytes[] | undefined |
| descriptionHash | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### modifyProposalThreshold

```solidity
function modifyProposalThreshold(uint256 __proposalThreshold) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| __proposalThreshold | uint256 | undefined |

### modifyVotingDelay

```solidity
function modifyVotingDelay(uint256 __votingDelay) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| __votingDelay | uint256 | undefined |

### modifyVotingPeriod

```solidity
function modifyVotingPeriod(uint256 __votingPeriod) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| __votingPeriod | uint256 | undefined |

### name

```solidity
function name() external view returns (string)
```



*See {IGovernor-name}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

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

### proposalDeadline

```solidity
function proposalDeadline(uint256 proposalId) external view returns (uint256)
```



*See {IGovernor-proposalDeadline}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### proposalEta

```solidity
function proposalEta(uint256 proposalId) external view returns (uint256)
```



*Public accessor to check the eta of a queued proposal*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### proposalProposer

```solidity
function proposalProposer(uint256 proposalId) external view returns (address)
```



*Returns the account that created a given proposal.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### proposalSnapshot

```solidity
function proposalSnapshot(uint256 proposalId) external view returns (uint256)
```



*See {IGovernor-proposalSnapshot}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### proposalThreshold

```solidity
function proposalThreshold() external view returns (uint256)
```



*Part of the Governor Bravo&#39;s interface: _&quot;The number of votes required in order for a voter to become a proposer&quot;_.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### proposals

```solidity
function proposals(uint256 proposalId) external view returns (uint256 id, address proposer, uint256 eta, uint256 startBlock, uint256 endBlock, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes, bool canceled, bool executed)
```



*See {IGovernorCompatibilityBravo-proposals}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| id | uint256 | undefined |
| proposer | address | undefined |
| eta | uint256 | undefined |
| startBlock | uint256 | undefined |
| endBlock | uint256 | undefined |
| forVotes | uint256 | undefined |
| againstVotes | uint256 | undefined |
| abstainVotes | uint256 | undefined |
| canceled | bool | undefined |
| executed | bool | undefined |

### propose

```solidity
function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| calldatas | bytes[] | undefined |
| description | string | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### propose

```solidity
function propose(address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, string description) external nonpayable returns (uint256)
```



*See {IGovernorCompatibilityBravo-propose}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| signatures | string[] | undefined |
| calldatas | bytes[] | undefined |
| description | string | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### queue

```solidity
function queue(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) external nonpayable returns (uint256)
```



*Function to queue a proposal to the timelock.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| targets | address[] | undefined |
| values | uint256[] | undefined |
| calldatas | bytes[] | undefined |
| descriptionHash | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### queue

```solidity
function queue(uint256 proposalId) external nonpayable
```



*See {IGovernorCompatibilityBravo-queue}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

### quorum

```solidity
function quorum(uint256 timepoint) external view returns (uint256)
```



*Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| timepoint | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### quorumDenominator

```solidity
function quorumDenominator() external view returns (uint256)
```



*Returns the quorum denominator. Defaults to 100, but may be overridden.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### quorumNumerator

```solidity
function quorumNumerator(uint256 timepoint) external view returns (uint256)
```



*Returns the quorum numerator at a specific timepoint. See {quorumDenominator}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| timepoint | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### quorumNumerator

```solidity
function quorumNumerator() external view returns (uint256)
```



*Returns the current quorum numerator. See {quorumDenominator}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### quorumVotes

```solidity
function quorumVotes() external view returns (uint256)
```



*See {IGovernorCompatibilityBravo-quorumVotes}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### relay

```solidity
function relay(address target, uint256 value, bytes data) external payable
```



*Relays a transaction or function call to an arbitrary target. In cases where the governance executor is some contract other than the governor itself, like when using a timelock, this function can be invoked in a governance proposal to recover tokens or Ether that was sent to the governor contract by mistake. Note that if the executor is simply the governor itself, use of `relay` is redundant.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| target | address | undefined |
| value | uint256 | undefined |
| data | bytes | undefined |

### state

```solidity
function state(uint256 proposalId) external view returns (enum IGovernor.ProposalState)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | enum IGovernor.ProposalState | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### timelock

```solidity
function timelock() external view returns (address)
```



*Public accessor to check the address of the timelock*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### token

```solidity
function token() external view returns (contract IERC5805)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC5805 | undefined |

### updateQuorumNumerator

```solidity
function updateQuorumNumerator(uint256 newQuorumNumerator) external nonpayable
```



*Changes the quorum numerator. Emits a {QuorumNumeratorUpdated} event. Requirements: - Must be called through a governance proposal. - New numerator must be smaller or equal to the denominator.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newQuorumNumerator | uint256 | undefined |

### updateTimelock

```solidity
function updateTimelock(contract TimelockController newTimelock) external nonpayable
```



*Public endpoint to update the underlying timelock instance. Restricted to the timelock itself, so updates must be proposed, scheduled, and executed through governance proposals. CAUTION: It is not recommended to change the timelock while there are other queued governance proposals.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newTimelock | contract TimelockController | undefined |

### version

```solidity
function version() external view returns (string)
```



*See {IGovernor-version}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### votingDelay

```solidity
function votingDelay() external view returns (uint256)
```

module:user-config

*Delay, between the proposal is created and the vote starts. The unit this duration is expressed in depends on the clock (see EIP-6372) this contract uses. This can be increased to leave time for users to buy voting power, or delegate it, before the voting of a proposal starts.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### votingPeriod

```solidity
function votingPeriod() external view returns (uint256)
```

module:user-config

*Delay between the vote start and vote end. The unit this duration is expressed in depends on the clock (see EIP-6372) this contract uses. NOTE: The {votingDelay} can delay the start of the vote. This must be considered when setting the voting duration compared to the voting delay.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### EIP712DomainChanged

```solidity
event EIP712DomainChanged()
```



*MAY be emitted to signal that the domain could have changed.*


### ProposalCanceled

```solidity
event ProposalCanceled(uint256 proposalId)
```



*Emitted when a proposal is canceled.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId  | uint256 | undefined |

### ProposalCreated

```solidity
event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)
```



*Emitted when a proposal is created.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId  | uint256 | undefined |
| proposer  | address | undefined |
| targets  | address[] | undefined |
| values  | uint256[] | undefined |
| signatures  | string[] | undefined |
| calldatas  | bytes[] | undefined |
| voteStart  | uint256 | undefined |
| voteEnd  | uint256 | undefined |
| description  | string | undefined |

### ProposalExecuted

```solidity
event ProposalExecuted(uint256 proposalId)
```



*Emitted when a proposal is executed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId  | uint256 | undefined |

### ProposalQueued

```solidity
event ProposalQueued(uint256 proposalId, uint256 eta)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| proposalId  | uint256 | undefined |
| eta  | uint256 | undefined |

### ProposalThresholdModified

```solidity
event ProposalThresholdModified(uint256 value)
```



*This event is emitted when the _proposalThreshold is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| value  | uint256 | is the new value of the _proposalThreshold. |

### QuorumNumeratorUpdated

```solidity
event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oldQuorumNumerator  | uint256 | undefined |
| newQuorumNumerator  | uint256 | undefined |

### TimelockChange

```solidity
event TimelockChange(address oldTimelock, address newTimelock)
```



*Emitted when the timelock controller used for proposal execution is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| oldTimelock  | address | undefined |
| newTimelock  | address | undefined |

### VoteCast

```solidity
event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason)
```



*Emitted when a vote is cast without params. Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| voter `indexed` | address | undefined |
| proposalId  | uint256 | undefined |
| support  | uint8 | undefined |
| weight  | uint256 | undefined |
| reason  | string | undefined |

### VoteCastWithParams

```solidity
event VoteCastWithParams(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params)
```



*Emitted when a vote is cast with params. Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used. `params` are additional encoded parameters. Their interpepretation also depends on the voting module used.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| voter `indexed` | address | undefined |
| proposalId  | uint256 | undefined |
| support  | uint8 | undefined |
| weight  | uint256 | undefined |
| reason  | string | undefined |
| params  | bytes | undefined |

### VotingDelayModified

```solidity
event VotingDelayModified(uint256 value)
```



*This event is emitted when the _votingDelay is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| value  | uint256 | is the new value of the _votingDelay. |

### VotingPeriodModified

```solidity
event VotingPeriodModified(uint256 value)
```



*This event is emitted when the _votingPeriod is modified.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| value  | uint256 | is the new value of the _votingPeriod. |



## Errors

### Empty

```solidity
error Empty()
```



*An operation (e.g. {front}) couldn&#39;t be completed due to the queue being empty.*


### InvalidShortString

```solidity
error InvalidShortString()
```






### StringTooLong

```solidity
error StringTooLong(string str)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| str | string | undefined |


