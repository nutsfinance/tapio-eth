// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/LPToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LPTokenTest is Test {
    LPToken public lpToken;
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

        bytes memory data = abi.encodeCall(LPToken.initialize, ("Tapio ETH", "lpToken"));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);

        lpToken = LPToken(address(proxy));
        lpToken.transferOwnership(governance);
    }

    function test_AddPool() public {
        vm.prank(governance);
        lpToken.addPool(pool1);

        assertEq(lpToken.pools(pool1), true);
    }

    function test_RemovePool() public {
        vm.prank(governance);
        lpToken.addPool(pool1);

        vm.prank(governance);
        lpToken.removePool(pool1);

        assertEq(lpToken.pools(pool1), false);
    }

    function test_MintSharesSingleUser() public {
        vm.prank(governance);
        lpToken.addPool(pool1);

        uint256 amount = 1_000_000_000_000_000_000_000;
        vm.prank(pool1);
        lpToken.mintShares(user1, amount);

        assertEq(lpToken.totalSupply(), amount);
        assertEq(lpToken.totalShares(), amount);
        assertEq(lpToken.sharesOf(user1), amount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.balanceOf(user1), amount - lpToken.NUMBER_OF_DEAD_SHARES());
    }

    function test_MintSharesMultipleUsers() public {
        vm.prank(governance);
        lpToken.addPool(pool1);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 2_000_000_000_000_000_000_000;
        uint256 amount3 = 3_000_000_000_000_000_000_000;

        vm.prank(pool1);
        lpToken.mintShares(user1, amount1);
        vm.prank(pool1);
        lpToken.mintShares(user2, amount2);
        vm.prank(pool1);
        lpToken.mintShares(user3, amount3);

        uint256 totalAmount = amount1 + amount2 + amount3;
        assertEq(lpToken.totalSupply(), totalAmount);
        assertEq(lpToken.totalShares(), totalAmount);
        assertEq(lpToken.sharesOf(user1), amount1 - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.balanceOf(user1), amount1 - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(user2), amount2);
        assertEq(lpToken.balanceOf(user2), amount2);
        assertEq(lpToken.sharesOf(user3), amount3);
        assertEq(lpToken.balanceOf(user3), amount3);
    }

    function test_BurnSharesSingleUser() public {
        vm.prank(governance);
        lpToken.addPool(pool1);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;

        vm.prank(pool1);
        lpToken.mintShares(user1, amount1);

        vm.prank(user1);
        lpToken.burnShares(amount2);

        uint256 deltaAmount = amount1 - amount2;
        assertEq(lpToken.totalSupply(), deltaAmount);
        assertEq(lpToken.totalShares(), deltaAmount);
        assertEq(lpToken.sharesOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.balanceOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
    }

    function test_AddTotalSupply() public {
        address user = vm.addr(0x5);
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 totalAmount = amount1 + amount2;

        vm.prank(governance);
        lpToken.addPool(pool1);

        vm.prank(pool1);
        lpToken.mintShares(user, amount1);

        vm.prank(pool1);
        lpToken.addTotalSupply(amount2);

        assertEq(lpToken.totalSupply(), totalAmount);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.totalRewards(), amount2);
        assertEq(lpToken.sharesOf(user), amount1 - lpToken.NUMBER_OF_DEAD_SHARES());

        /// 1000 shares worth of supply goes to address(0) when amount 1 was minted
        ///
        assertEq(lpToken.balanceOf(user), (amount1 - lpToken.NUMBER_OF_DEAD_SHARES()) + (amount2 - 500 wei));
    }

    function testApprove() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount = 1_000_000_000_000_000_000_000;

        // User approves spender
        vm.prank(user);
        lpToken.approve(spender, amount);

        // Check that the allowance is updated correctly
        assertEq(lpToken.allowance(user, spender), amount);
    }

    function test_IncreaseAllowance() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 2_000_000_000_000_000_000_000;
        uint256 totalAmount = amount1 + amount2;

        // User approves spender with an initial amount
        vm.prank(user);
        lpToken.approve(spender, amount1);

        // User increases the allowance
        vm.prank(user);
        lpToken.increaseAllowance(spender, amount2);

        // Check that the total allowance is updated correctly
        assertEq(lpToken.allowance(user, spender), totalAmount);
    }

    function test_Approve() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);
        uint256 amount = 1_000_000_000_000_000_000_000;

        // User approves spender
        vm.prank(user);
        lpToken.approve(spender, amount);

        // Check that the allowance is updated correctly
        assertEq(lpToken.allowance(user, spender), amount);
    }

    function test_DecreaseAllowance() public {
        address user = vm.addr(0x5);
        address spender = vm.addr(0x6);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 totalAmount = amount1 - amount2;

        // User approves spender
        vm.prank(user);
        lpToken.approve(spender, amount1);

        // User decreases the allowance
        vm.prank(user);
        lpToken.decreaseAllowance(spender, amount2);

        // Assert the updated allowance
        assertEq(lpToken.allowance(user, spender), totalAmount);
    }

    function test_TransferShares() public {
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 deltaAmount = amount1 - amount2;

        // Governance adds pool
        vm.prank(governance);
        lpToken.addPool(pool1);

        // Pool mints shares to user1
        vm.prank(pool1);
        lpToken.mintShares(user1, amount1);

        // User1 transfers shares to user2
        vm.prank(user1);
        lpToken.transferShares(user2, amount2);

        // Assertions
        assertEq(lpToken.totalSupply(), amount1);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.sharesOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(user2), amount2);
        assertEq(lpToken.balanceOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.balanceOf(user2), amount2);
    }

    function test_TransferSharesFrom() public {
        address spender = vm.addr(0x7);

        uint256 amount1 = 1_000_000_000_000_000_000_000;
        uint256 amount2 = 500_000_000_000_000_000_000;
        uint256 deltaAmount = amount1 - amount2;

        // Governance adds pool
        vm.prank(governance);
        lpToken.addPool(pool1);

        // Pool mints shares to user1
        vm.prank(pool1);
        lpToken.mintShares(user1, amount1);

        // User1 approves spender
        vm.prank(user1);
        lpToken.approve(spender, amount1);

        // Spender transfers shares from user1 to user2
        vm.prank(spender);
        lpToken.transferSharesFrom(user1, user2, amount2);

        // Assertions
        assertEq(lpToken.totalSupply(), amount1);
        assertEq(lpToken.totalShares(), amount1);
        assertEq(lpToken.sharesOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.sharesOf(user2), amount2);
        assertEq(lpToken.balanceOf(user1), deltaAmount - lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(lpToken.balanceOf(user2), amount2);
        assertEq(lpToken.allowance(user1, spender), deltaAmount);
    }
}
