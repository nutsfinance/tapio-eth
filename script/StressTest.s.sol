// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "./Config.sol";
import "../src/mock/MockToken.sol";
import "../src/SelfPeggingAsset.sol";

contract StressTestScript is Script, Config, Test {
    MockToken public tokenA;
    MockToken public tokenB;
    SelfPeggingAsset public pool;

    address public user;
    uint256 public constant INITIAL_AMOUNT = 10_000e18;

    address poolAddress;
    address tokenAAddress;
    address tokenBAddress;

    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function stressTest(uint256 iterations) internal {
        tokenA = MockToken(tokenAAddress);
        tokenB = MockToken(tokenBAddress);
        pool = SelfPeggingAsset(poolAddress);
        user = DEPLOYER;

        for (uint256 i = 0; i < iterations; i++) {
            uint256 testAmount = randomAmount(i);

            tokenA.mint(user, INITIAL_AMOUNT);
            tokenB.mint(user, INITIAL_AMOUNT);

            approveTokenPool();

            poolMint(testAmount);

            poolSwap(tokenA, 0, 1, testAmount);
            poolSwap(tokenB, 1, 0, testAmount);

            poolRedeem(0, testAmount);
            poolRedeem(1, testAmount);

            approveTokenPool();
            
            poolDonate(testAmount);
        }
    }

    function randomAmount(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, seed))) % 1000e18;
    }

    function approveTokenPool() internal {
        tokenA.approve(address(pool), INITIAL_AMOUNT);
        tokenB.approve(address(pool), INITIAL_AMOUNT);
    }

    function poolMint(uint256 amount) internal {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        pool.mint(amounts, 0);
    }

    function poolSwap(MockToken token, uint256 tokenInIndex, uint256 tokenOutIndex, uint256 amount) internal {
        require(tokenInIndex != tokenOutIndex, "Cannot swap the same token");

        token.approve(address(pool), amount);

        pool.swap(tokenInIndex, tokenOutIndex, amount, 0);
    }

    function poolRedeem(uint256 tokenIndex, uint256 amount) internal {
        uint256 redeemAmount = pool.poolToken().balanceOf(user);
        
        if (redeemAmount > 0) {
            pool.poolToken().approve(address(pool), redeemAmount);

            // Ensure amount does not exceed redeemable balance
            uint256 safeAmount = amount > redeemAmount ? redeemAmount : amount;

            if (randomAmount(tokenIndex) % 2 == 0) {
                pool.redeemSingle(safeAmount, tokenIndex, 0);
            } else {
                uint256[] memory minRedeemAmounts = new uint256[](2);
                minRedeemAmounts[0] = 0;
                minRedeemAmounts[1] = 0;
                pool.redeemProportion(redeemAmount, minRedeemAmounts);
            }
        }
    }

    function poolDonate(uint256 amount) internal {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        pool.donateD(amounts, 0);
    }

    function run() public payable {
        init();
        poolAddress = vm.envAddress("POOL_ADDRESS");
        tokenAAddress = vm.envAddress("TOKEN_A");
        tokenBAddress = vm.envAddress("TOKEN_B");

        vm.startBroadcast(deployerPrivateKey);
        stressTest(1);
        vm.stopBroadcast();
    }
}
