// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/**
 * @title VotingToken
 * @author Nuts Finance Developer
 * @notice ERC20 token used by the VotingEscrow
 * @dev The VotingToken contract represents the ERC20 token used by the VotingEscrow
 * This token can be minted by designated minters and burned by its owner. The governance address can
 * be updated to change who has the ability to manage minters and other aspects of the token
 */
contract VotingToken is ERC20BurnableUpgradeable {
  /**
   * @dev Emitted when the governance address is updated.
   * @param account Address of the new governance.
   */
  event MinterUpdated(address indexed account, bool allowed);

  /**
   * @dev This event is emitted when the governance is modified.
   * @param governance is the new value of the governance.
   */
  event GovernanceModified(address governance);

  /**
   * @dev This event is emitted when the governance is modified.
   * @param governance is the new value of the governance.
   */
  event GovernanceProposed(address governance);

  /**
   * @dev Governance address for the token.
   */
  address public governance;

  /**
   * @dev Mapping of minters.
   */
  mapping(address => bool) public minters;

  /**
   * @dev Pending governance address for the token.
   */
  address public pendingGovernance;

  /**
   * @dev Initializes token contract.
   * @param _name Name of the token.
   * @param _symbol Symbol of the token.
   */
  function initialize(
    string memory _name,
    string memory _symbol
  ) public initializer {
    __ERC20_init(_name, _symbol);
    governance = msg.sender;
  }

  /**
   * @dev Propose the govenance address.
   * @param _governance Address of the new governance.
   */
  function proposeGovernance(address _governance) public {
    require(msg.sender == governance, "not governance");
    pendingGovernance = _governance;
    emit GovernanceProposed(_governance);
  }

  /**
   * @dev Accept the govenance address.
   */
  function acceptGovernance() public {
    require(msg.sender == pendingGovernance, "not pending governance");
    governance = pendingGovernance;
    pendingGovernance = address(0);
    emit GovernanceModified(governance);
  }

  /**
   * @dev Sets minter for token. Only minter can mint token.
   * @param _user Address of the minter.
   * @param _allowed Whether the user is accepted as a minter or not.
   */
  function setMinter(address _user, bool _allowed) public {
    require(msg.sender == governance, "not governance");
    minters[_user] = _allowed;

    emit MinterUpdated(_user, _allowed);
  }

  /**
   * @dev Mints new token. Only minters can mint token.
   * @param _user Recipient of the minted token.
   * @param _amount Amount of token to mint.
   */
  function mint(address _user, uint256 _amount) public {
    require(minters[msg.sender], "not minter");
    _mint(_user, _amount);
  }
}
