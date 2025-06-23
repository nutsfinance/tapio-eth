// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SPAToken interface
 * @author Nuts Finance Developer
 * @notice Interface for SPAToken
 */
interface ISPAToken is IERC20 {
    /// @dev Increase the allowance of the spender
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);

    /// @dev Decrease the allowance of the spender
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);

    /// @dev Add the amount to the total supply
    function addTotalSupply(uint256 _amount) external;

    /// @dev Remove the amount from the total supply
    function removeTotalSupply(uint256 _amount, bool isBuffer, bool withDebt) external;

    /// @dev Transfer the shares to the recipient
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    /// @dev Transfer the shares from the sender to the recipient
    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    )
        external
        returns (uint256);

    /// @dev Mint the shares to the account
    function mintShares(address _account, uint256 _sharesAmount) external;

    /// @dev Burn the shares from the account
    function burnShares(uint256 _sharesAmount) external;

    /// @dev Burn the shares from the account
    function burnSharesFrom(address _account, uint256 _sharesAmount) external;

    // @dev Add to buffer
    function addBuffer(uint256 _amount) external;

    // @dev Withdraw from buffer
    function withdrawBuffer(address _to, uint256 _amount) external;

    /// @dev Name of the token
    function name() external view returns (string memory);

    /// @dev Symbol of the token
    function symbol() external view returns (string memory);

    /// @dev Get the total amount of shares
    function totalShares() external view returns (uint256);

    /// @dev Get the total amount of rewards
    function totalRewards() external view returns (uint256);

    /// @dev Get the total shares of the account
    function sharesOf(address _account) external view returns (uint256);

    /// @dev Get the shares corresponding to the amount of pooled eth
    function getSharesByPeggedToken(uint256 _ethAmount) external view returns (uint256);

    /// @dev Add the amount of Eth corresponding to the shares
    function getPeggedTokenByShares(uint256 _sharesAmount) external view returns (uint256);
}
