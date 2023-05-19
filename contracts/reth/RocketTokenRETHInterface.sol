// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface RocketTokenRETHInterface is IERC20 {
    function getEthValue(uint256 _rethAmount) external view returns (uint256);
    function getRethValue(uint256 _ethAmount) external view returns (uint256);
    function getExchangeRate() external view returns (uint256);
    function getTotalCollateral() external view returns (uint256);
    function getCollateralRate() external view returns (uint256);
    function depositExcess() external payable;
    function depositExcessCollateral() external;
    function mint(uint256 _ethAmount, address _to) external;
    function burn(uint256 _rethAmount) external;
}
