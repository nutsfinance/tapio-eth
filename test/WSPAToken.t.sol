// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SPAToken.sol";
import "../src/WSPAToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WSPATokenTest is Test {
    SPAToken public spaToken;
    WSPAToken public wspaToken;

    address public owner;
    address public governance;
    address public pool1;
    address public pool2;
    address public user;

    function setUp() public {
        owner = vm.addr(1);
        governance = vm.addr(2);
        pool1 = vm.addr(3);
        pool2 = vm.addr(4);
        user = vm.addr(5);

        vm.startPrank(owner);

        bytes memory data = abi.encodeCall(SPAToken.initialize, ("Tapio ETH", "TapETH", 0, owner, address(pool1)));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), data);
        spaToken = SPAToken(address(proxy));

        data = abi.encodeCall(WSPAToken.initialize, (spaToken));

        proxy = new ERC1967Proxy(address(new WSPAToken()), data);
        wspaToken = WSPAToken(address(proxy));

        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wspaTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Mint shares to user
        vm.prank(pool1);
        spaToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        spaToken.addTotalSupply(amount2);

        // Approve wspaToken contract
        vm.prank(user);
        spaToken.approve(address(wspaToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wspaToken.deposit(amountToWrap, user);

        // Assertions
        assertEq(spaToken.totalSupply(), targetTotalSupply);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.sharesOf(user), amount1 - wspaTokenTargetAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(address(wspaToken)), wspaTokenTargetAmount);
        assertEq(spaToken.balanceOf(address(wspaToken)), amountToWrap);
        assertEq(wspaToken.balanceOf(user), wspaTokenTargetAmount);
    }

    function testRedeem() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wspaTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Mint shares to user
        vm.prank(pool1);
        spaToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        spaToken.addTotalSupply(amount2);

        // Approve wspaToken contract
        vm.prank(user);
        spaToken.approve(address(wspaToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wspaToken.deposit(amountToWrap, user);

        // Unwrap tokens
        vm.prank(user);
        wspaToken.redeem(wspaTokenTargetAmount, user, user);

        // Assertions
        assertEq(spaToken.totalSupply(), targetTotalSupply);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.sharesOf(user), amount1 - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(address(wspaToken)), 0);
        assertEq(spaToken.balanceOf(address(wspaToken)), 0);
        assertEq(wspaToken.balanceOf(user), 0);
        assertEq(wspaToken.totalAssets(), 0);
    }

    function testWithdraw() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wspaTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Mint shares to user
        vm.prank(pool1);
        spaToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        spaToken.addTotalSupply(amount2);

        // Approve wspaToken contract
        vm.prank(user);
        spaToken.approve(address(wspaToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wspaToken.deposit(amountToWrap, user);

        // Unwrap tokens
        uint256 assets = wspaToken.convertToAssets(wspaTokenTargetAmount);
        vm.prank(user);
        wspaToken.withdraw(assets, user, user);

        // Assertions
        assertEq(spaToken.totalSupply(), targetTotalSupply);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.sharesOf(user), amount1 - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(address(wspaToken)), 0);
        assertEq(spaToken.balanceOf(address(wspaToken)), 0);
        assertEq(wspaToken.balanceOf(user), 0);
        assertEq(wspaToken.totalAssets(), 0);
    }
}
