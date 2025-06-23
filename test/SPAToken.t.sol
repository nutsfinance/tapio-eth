// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SPAToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract spaTokenTest is Test {
    SPAToken public spaToken;
    address public governance;
    address public pool1;
    address public pool2;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        governance = makeAddr("governance");
        pool1 = makeAddr("pool1");
        pool2 = makeAddr("pool2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        bytes memory data = abi.encodeCall(SPAToken.initialize, ("Tapio ETH", "spaToken", 0, governance, pool1));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), data);
        spaToken = SPAToken(address(proxy));
        assertEq(spaToken.pool(), pool1);
    }

    function test_MintSharesSingleUser() public {
        uint256 amount = 1_000_000_000_000_000_000_000;
        vm.prank(pool1);
        spaToken.mintShares(user1, amount);

        assertEq(spaToken.totalSupply(), amount);
        assertEq(spaToken.totalShares(), amount);
        assertEq(spaToken.sharesOf(user1), amount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.balanceOf(user1), amount - spaToken.NUMBER_OF_DEAD_SHARES());
    }

    function test_MintSharesMultipleUsers() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 2_000_000_000_000_000_000_000;
        uint256 amount3 = 3_000_000_000_000_000_000_000;

        vm.prank(pool1);
        spaToken.mintShares(user1, amount1);
        vm.prank(pool1);
        spaToken.mintShares(user2, amount2);
        vm.prank(pool1);
        spaToken.mintShares(user3, amount3);

        uint256 totalAmount = amount1 + amount2 + amount3;
        assertEq(spaToken.totalSupply(), totalAmount);
        assertEq(spaToken.totalShares(), totalAmount);
        assertEq(spaToken.sharesOf(user1), amount1 - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.balanceOf(user1), amount1 - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(user2), amount2);
        assertEq(spaToken.balanceOf(user2), amount2);
        assertEq(spaToken.sharesOf(user3), amount3);
        assertEq(spaToken.balanceOf(user3), amount3);
    }

    function test_BurnSharesSingleUser() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;

        vm.prank(pool1);
        spaToken.mintShares(user1, amount1);

        vm.prank(user1);
        spaToken.burnShares(amount2);

        uint256 deltaAmount = amount1 - amount2;
        assertEq(spaToken.totalSupply(), deltaAmount);
        assertEq(spaToken.totalShares(), deltaAmount);
        assertEq(spaToken.sharesOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.balanceOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
    }

    function test_AddTotalSupply() public {
        address user = vm.addr(0x5);
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 totalAmount = amount1 + amount2;

        vm.prank(pool1);
        spaToken.mintShares(user, amount1);

        vm.prank(pool1);
        spaToken.addTotalSupply(amount2);

        assertEq(spaToken.totalSupply(), totalAmount);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.totalRewards(), amount2);
        assertEq(spaToken.sharesOf(user), amount1 - spaToken.NUMBER_OF_DEAD_SHARES());

        /// 1000 shares worth of supply goes to address(0) when amount 1 was minted
        ///
        assertEq(spaToken.balanceOf(user), (amount1 - spaToken.NUMBER_OF_DEAD_SHARES()) + (amount2 - 500 wei));
    }

    function testApprove() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount = 1_000_000_000_000_000_000_000;

        // User approves spender
        vm.prank(user);
        spaToken.approve(spender, amount);

        // Check that the allowance is updated correctly
        assertEq(spaToken.allowance(user, spender), amount);
    }

    function test_IncreaseAllowance() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 2_000_000_000_000_000_000_000;
        uint256 totalAmount = amount1 + amount2;

        // User approves spender with an initial amount
        vm.prank(user);
        spaToken.approve(spender, amount1);

        // User increases the allowance
        vm.prank(user);
        spaToken.increaseAllowance(spender, amount2);

        // Check that the total allowance is updated correctly
        assertEq(spaToken.allowance(user, spender), totalAmount);
    }

    function test_Approve() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount = 1_000_000_000_000_000_000_000;

        // User approves spender
        vm.prank(user);
        spaToken.approve(spender, amount);

        // Check that the allowance is updated correctly
        assertEq(spaToken.allowance(user, spender), amount);
    }

    function test_DecreaseAllowance() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 totalAmount = amount1 - amount2;

        // User approves spender
        vm.prank(user);
        spaToken.approve(spender, amount1);

        // User decreases the allowance
        vm.prank(user);
        spaToken.decreaseAllowance(spender, amount2);

        // Assert the updated allowance
        assertEq(spaToken.allowance(user, spender), totalAmount);
    }

    function test_TransferShares() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 deltaAmount = amount1 - amount2;

        // Pool mints shares to user1
        vm.prank(pool1);
        spaToken.mintShares(user1, amount1);

        // User1 transfers shares to user2
        vm.prank(user1);
        spaToken.transferShares(user2, amount2);

        // Assertions
        assertEq(spaToken.totalSupply(), amount1);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.sharesOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(user2), amount2);
        assertEq(spaToken.balanceOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.balanceOf(user2), amount2);
    }

    function test_TransferSharesFrom() public {
        address spender = vm.addr(0x7);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 deltaAmount = amount1 - amount2;

        // Pool mints shares to user1
        vm.prank(pool1);
        spaToken.mintShares(user1, amount1);

        // User1 approves spender
        vm.prank(user1);
        spaToken.approve(spender, amount1);

        // Spender transfers shares from user1 to user2
        vm.prank(spender);
        spaToken.transferSharesFrom(user1, user2, amount2);

        // Assertions
        assertEq(spaToken.totalSupply(), amount1);
        assertEq(spaToken.totalShares(), amount1);
        assertEq(spaToken.sharesOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.sharesOf(user2), amount2);
        assertEq(spaToken.balanceOf(user1), deltaAmount - spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(spaToken.balanceOf(user2), amount2);
        assertEq(spaToken.allowance(user1, spender), deltaAmount);
    }
}
