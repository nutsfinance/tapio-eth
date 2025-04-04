pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SelfPeggingAsset.sol";
import "../src/mock/MockToken.sol";
import "../src/mock/MockExchangeRateProvider.sol";
import "../src/LPToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SelfPeggingAssetFuzzTest is Test {
    SelfPeggingAsset pool;
    MockToken tokenI;
    MockToken tokenJ;
    MockExchangeRateProvider providerI;
    MockExchangeRateProvider providerJ;
    LPToken lpToken;

    address owner = address(this);
    address user = address(0x123);

    uint256 constant A = 1000;
    uint256 constant FEE_DENOMINATOR = 1e10;
    uint256 constant RATE_CHANGE_FEE_STALE_WINDOW = 1 hours;

    function setUp() public {
        // Deploy tokens
        tokenI = new MockToken("rETH", "rETH", 18);
        tokenJ = new MockToken("wstETH", "wstETH", 18);

        // Deploy exchange rate providers with initial rate 1e18
        providerI = new MockExchangeRateProvider(1e18, 18);
        providerJ = new MockExchangeRateProvider(1e18, 18);

        // Deploy LPToken
        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));
        ERC1967Proxy lpProxy = new ERC1967Proxy(address(new LPToken()), data);
        lpToken = LPToken(address(lpProxy));
        lpToken.transferOwnership(owner);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenI);
        tokens[1] = address(tokenJ);

        uint256[] memory precisions = new uint256[](2);
        precisions[0] = 1; // 18 decimals, precision = 1
        precisions[1] = 1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = 0; // mintFee
        fees[1] = 0; // swapFee
        fees[2] = 0; // redeemFee

        IExchangeRateProvider[] memory providers = new IExchangeRateProvider[](2);
        providers[0] = IExchangeRateProvider(providerI);
        providers[1] = IExchangeRateProvider(providerJ);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize, (tokens, precisions, fees, 0, lpToken, A, providers, address(0), 0)
        );

        ERC1967Proxy poolProxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        pool = SelfPeggingAsset(address(poolProxy));
        pool.transferOwnership(owner);

        // Add pool to LPToken
        vm.prank(owner);
        lpToken.addPool(address(pool));

        // Mint initial liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        tokenI.mint(user, 100e18);
        tokenJ.mint(user, 100e18);

        vm.startPrank(user);
        tokenI.approve(address(pool), 100e18);
        tokenJ.approve(address(pool), 100e18);
        pool.mint(amounts, 0);
        vm.stopPrank();

        vm.prank(address(pool));
        lpToken.addBuffer(100e18); // Add 100e18 buffer
    }

    function testFuzz_SwapFeeWithExchangeRateChanges(
        int256 rateChangeIPercent,
        int256 rateChangeJPercent,
        uint256 exchangeRateFeeFactor,
        uint256 swapAmount
    )
        public
    {
        // Exchange rate changes: -5% to +5%
        rateChangeIPercent = bound(rateChangeIPercent, -5, 5);
        rateChangeJPercent = bound(rateChangeJPercent, -5, 5);
        // exchangeRateFeeFactor: 0% to 10% (0 to 0.1e10)
        exchangeRateFeeFactor = bound(exchangeRateFeeFactor, 0, 0.1e10);
        // amount 0.0001 eth to 1 eth
        swapAmount = bound(swapAmount, 1e14, 1e18);

        uint256 initialRateI = 1e18;
        uint256 initialRateJ = 1e18;
        uint256 newExchangeRateI = rateChangeIPercent > 0
            ? initialRateI + (initialRateI * uint256(rateChangeIPercent)) / 100
            : initialRateI - (initialRateI * uint256(rateChangeIPercent * -1)) / 100;
        uint256 newExchangeRateJ = rateChangeJPercent > 0
            ? initialRateJ + (initialRateJ * uint256(rateChangeJPercent)) / 100
            : initialRateJ - (initialRateJ * uint256(rateChangeJPercent * -1)) / 100;

        providerI.setExchangeRate(newExchangeRateI);
        providerJ.setExchangeRate(newExchangeRateJ);

        // uint256 swapAmount = 1e18;
        tokenI.mint(user, swapAmount);

        // rETH to wstETH
        vm.startPrank(user);
        tokenI.approve(address(pool), swapAmount);
        uint256 dy = pool.swap(0, 1, swapAmount, 0);
        vm.stopPrank();

        uint256 lastExchangeRateI = 1e18;
        uint256 lastExchangeRateJ = 1e18;

        uint256 exchangeRateFeeI;
        if (newExchangeRateI > lastExchangeRateI) {
            exchangeRateFeeI = (newExchangeRateI - lastExchangeRateI) * FEE_DENOMINATOR / lastExchangeRateI;
        } else {
            exchangeRateFeeI = (lastExchangeRateI - newExchangeRateI) * FEE_DENOMINATOR / lastExchangeRateI;
        }
        exchangeRateFeeI = (exchangeRateFeeI * exchangeRateFeeFactor) / FEE_DENOMINATOR;

        uint256 exchangeRateFeeJ;
        if (newExchangeRateJ > lastExchangeRateJ) {
            exchangeRateFeeJ = (newExchangeRateJ - lastExchangeRateJ) * FEE_DENOMINATOR / lastExchangeRateJ;
        } else {
            exchangeRateFeeJ = (lastExchangeRateJ - newExchangeRateJ) * FEE_DENOMINATOR / lastExchangeRateJ;
        }
        exchangeRateFeeJ = (exchangeRateFeeJ * exchangeRateFeeFactor) / FEE_DENOMINATOR;

        uint256 totalFee = exchangeRateFeeI + exchangeRateFeeJ;

        // Calculate dyBeforeFee based on exchange rates
        uint256 dyBeforeFee = (swapAmount * newExchangeRateI) / newExchangeRateJ;

        uint256 expectedFee = (dyBeforeFee * totalFee) / FEE_DENOMINATOR;
        uint256 expectedDy = dyBeforeFee > expectedFee ? dyBeforeFee - expectedFee : 0;

        // Use a small tolerance (0.1 ether) for rounding errors
        if (expectedDy > 0) {
            assertApproxEqAbs(dy, expectedDy, 1e17, "Swap output does not match expected output within tolerance");
        } else {
            assertEq(dy, 0, "Expected zero output when fee exceeds dy");
        }
    }
}
