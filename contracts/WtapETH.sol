// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/ITapETH.sol";

contract WtaptETH is ERC20Permit {
    ITapETH public tapETH;

    constructor(
        ITapETH _tapETH
    ) public ERC20Permit("Wrapped tapETH") ERC20("Wrapped tapETH", "wtapETH") {
        tapETH = _tapETH;
    }

    function wrap(uint256 _tapETHAmount) external returns (uint256) {
        require(_tapETHAmount > 0, "wtapETH: can't wrap zero tapETH");
        uint256 _wtapETHAmount = tapETH.getSharesByPooledEth(_tapETHAmount);
        _mint(msg.sender, _wtapETHAmount);
        tapETH.transferFrom(msg.sender, address(this), _tapETHAmount);
        return _wtapETHAmount;
    }

    function unwrap(uint256 _wtapETHAmount) external returns (uint256) {
        require(_wtapETHAmount > 0, "wstETH: zero amount unwrap not allowed");
        uint256 _tapETHAmount = tapETH.getPooledEthByShares(_wtapETHAmount);
        _burn(msg.sender, _wtapETHAmount);
        tapETH.transfer(msg.sender, _tapETHAmount);
        return _tapETHAmount;
    }

    receive() external payable {
        // uint256 shares = tapETH.submit{value: msg.value}(address(0));
        //_mint(msg.sender, shares);
    }

    function getWtapETHByTapETH(
        uint256 _tapETHAmount
    ) external view returns (uint256) {
        return tapETH.getSharesByPooledEth(_tapETHAmount);
    }

    function getTapETHByWtapETH(
        uint256 _wtapETHAmount
    ) external view returns (uint256) {
        return tapETH.getPooledEthByShares(_wtapETHAmount);
    }

    function tapETHPerToken() external view returns (uint256) {
        return tapETH.getPooledEthByShares(1 ether);
    }

    function tokensPerTapETH() external view returns (uint256) {
        return tapETH.getSharesByPooledEth(1 ether);
    }
}
