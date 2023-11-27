# IWETH

*Nuts Finance Developer*

> IWETH interface

Interface for WETH



## Methods

### deposit

```solidity
function deposit() external payable
```



*Deposit ether to get wrapped ether.*


### transfer

```solidity
function transfer(address to, uint256 value) external nonpayable returns (bool)
```



*Transfer wrapped ether to get ether.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | The address of the receiver. |
| value | uint256 | The amount of wrapped ether to transfer. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Whether the transfer succeeds. |

### withdraw

```solidity
function withdraw(uint256 value) external nonpayable
```



*Withdraw wrapped ether to get ether.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| value | uint256 | The amount of wrapped ether to withdraw. |




