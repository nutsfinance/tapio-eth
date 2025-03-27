// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/LPToken.sol";
import "../src/WLPToken.sol";

contract WLPTokenTest is Test {
    LPToken public lpToken;
    WLPToken public wlpToken;

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

        lpToken = new LPToken();
        lpToken.initialize("Tapio ETH", "TapETH");
        lpToken.transferOwnership(governance);

        wlpToken = new WLPToken();
        wlpToken.initialize(lpToken);

        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wlpTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Add pool
        vm.prank(governance);
        lpToken.addPool(pool1);

        // Mint shares to user
        vm.prank(pool1);
        lpToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        lpToken.addTotalSupply(amount2);

        // Approve wlpToken contract
        vm.prank(user);
        lpToken.approve(address(wlpToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wlpToken.deposit(amountToWrap, user);

        // Assertions
        assertEq(lpToken.totalSupply(), targetTotalSupply);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.sharesOf(user), amount1 - wlpTokenTargetAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(address(wlpToken)), wlpTokenTargetAmount);
        assertEq(lpToken.balanceOf(address(wlpToken)), amountToWrap);
        assertEq(wlpToken.balanceOf(user), wlpTokenTargetAmount);
    }

    function testRedeem() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wlpTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Add pool
        vm.prank(governance);
        lpToken.addPool(pool1);

        // Mint shares to user
        vm.prank(pool1);
        lpToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        lpToken.addTotalSupply(amount2);

        // Approve wlpToken contract
        vm.prank(user);
        lpToken.approve(address(wlpToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wlpToken.deposit(amountToWrap, user);

        // Unwrap tokens
        vm.prank(user);
        wlpToken.redeem(wlpTokenTargetAmount, user, user);

        // Assertions
        assertEq(lpToken.totalSupply(), targetTotalSupply);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.sharesOf(user), amount1 - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(address(wlpToken)), 0);
        assertEq(lpToken.balanceOf(address(wlpToken)), 0);
        assertEq(wlpToken.balanceOf(user), 0);
        assertEq(wlpToken.totalAssets(), 0);
    }

    function testWithdraw() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 amountToWrap = 300_000_000_000_000_000_000;

        uint256 targetTotalSupply = amount1 + amount2;
        uint256 wlpTokenTargetAmount = (amountToWrap * amount1) / targetTotalSupply;

        // Add pool
        vm.prank(governance);
        lpToken.addPool(pool1);

        // Mint shares to user
        vm.prank(pool1);
        lpToken.mintShares(user, amount1);

        // Increase total supply
        vm.prank(pool1);
        lpToken.addTotalSupply(amount2);

        // Approve wlpToken contract
        vm.prank(user);
        lpToken.approve(address(wlpToken), amountToWrap);

        // Wrap tokens
        vm.prank(user);
        wlpToken.deposit(amountToWrap, user);

        // Unwrap tokens
        uint256 assets = wlpToken.convertToAssets(wlpTokenTargetAmount);
        vm.prank(user);
        wlpToken.withdraw(assets, user, user);

        // Assertions
        assertEq(lpToken.totalSupply(), targetTotalSupply);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.sharesOf(user), amount1 - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(address(wlpToken)), 0);
        assertEq(lpToken.balanceOf(address(wlpToken)), 0);
        assertEq(wlpToken.balanceOf(user), 0);
        assertEq(wlpToken.totalAssets(), 0);
    }
}
