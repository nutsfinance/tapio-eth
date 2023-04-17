// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract StableSwapToken is ERC20BurnableUpgradeable {
  event MinterUpdated(address indexed account, bool allowed);

  address public governance;
  mapping(address => bool) public minters;

  /**
   * @dev Initializes stable swap token contract.
   */
  function initialize(
    string memory name,
    string memory symbol
  ) public initializer {
    __ERC20_init(name, symbol);
    governance = msg.sender;
  }

  /**
   * @dev Updates the govenance address.
   */
  function setGovernance(address _governance) public {
    require(msg.sender == governance, "not governance");
    governance = _governance;
  }

  /**
   * @dev Sets minter for acBTC. Only minter can mint acBTC.
   * @param _user Address of the minter.
   * @param _allowed Whether the user is accepted as a minter or not.
   */
  function setMinter(address _user, bool _allowed) public {
    require(msg.sender == governance, "not governance");
    minters[_user] = _allowed;

    emit MinterUpdated(_user, _allowed);
  }

  /**
   * @dev Mints new acBTC. Only minters can mint acBTC.
   * @param _user Recipient of the minted acBTC.
   * @param _amount Amount of acBTC to mint.
   */
  function mint(address _user, uint256 _amount) public {
    require(minters[msg.sender], "not minter");
    _mint(_user, _amount);
  }
}
