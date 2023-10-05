// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract TapioGovernor is
  Governor,
  GovernorCompatibilityBravo,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorTimelockControl
{
  /**
   * @dev This is the account that has governance control over the TapioGovernor contract.
   */
  address public governance;
  uint256 public _votingDelay;
  uint256 public _votingPeriod;
  uint256 public _proposalThreshold;

  /**
   * @dev This event is emitted when the _votingDelay is modified.
   * @param value is the new value of the _votingDelay.
   */
  event VotingDelayModified(uint256 value);

  /**
   * @dev This event is emitted when the _votingPeriod is modified.
   * @param value is the new value of the _votingPeriod.
   */
  event VotingPeriodModified(uint256 value);

  /**
   * @dev This event is emitted when the _proposalThreshold is modified.
   * @param value is the new value of the _proposalThreshold.
   */
  event ProposalThresholdModified(uint256 value);

  constructor(
    IVotes _token,
    TimelockController _timelock,
    uint256 __votingDelay,
    uint256 __votingPeriod,
    uint256 __proposalThreshold
  )
    Governor("TapioGovernor")
    GovernorVotes(_token)
    GovernorVotesQuorumFraction(4)
    GovernorTimelockControl(_timelock)
  {
    governance = address(this);
    _votingDelay = __votingDelay;
    _votingPeriod = __votingPeriod;
    _proposalThreshold = __proposalThreshold;
  }

  function votingDelay() public view override returns (uint256) {
    return _votingDelay;
  }

  function votingPeriod() public view override returns (uint256) {
    return _votingPeriod;
  }

  function proposalThreshold() public view override returns (uint256) {
    return _proposalThreshold;
  }

  function modifyVotingDelay(uint256 __votingDelay) external {
    require(msg.sender == governance, "not governance");
    _votingDelay = __votingDelay;
    emit VotingDelayModified(__votingDelay);
  }

  function modifyVotingPeriod(uint256 __votingPeriod) external {
    require(msg.sender == governance, "not governance");
    _votingPeriod = __votingPeriod;
    emit VotingPeriodModified(__votingPeriod);
  }

  function modifyProposalThreshold(uint256 __proposalThreshold) external {
    require(msg.sender == governance, "not governance");
    _proposalThreshold = __proposalThreshold;
    emit ProposalThresholdModified(__proposalThreshold);
  }

  // The functions below are overrides required by Solidity.

  function state(
    uint256 proposalId
  )
    public
    view
    override(Governor, IGovernor, GovernorTimelockControl)
    returns (ProposalState)
  {
    return super.state(proposalId);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  )
    public
    override(Governor, GovernorCompatibilityBravo, IGovernor)
    returns (uint256)
  {
    return super.propose(targets, values, calldatas, description);
  }

  function _execute(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._execute(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executor()
    internal
    view
    override(Governor, GovernorTimelockControl)
    returns (address)
  {
    return super._executor();
  }

  function supportsInterface(
    bytes4 interfaceId
  )
    public
    view
    override(Governor, IERC165, GovernorTimelockControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
