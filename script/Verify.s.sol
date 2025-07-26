// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { IRampAController } from "../src/interfaces/IRampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { Config } from "script/Config.sol";

contract Verify is Script, Config {
    using stdJson for string;

    bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 initializedSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    address private spa;
    address private keeper;
    address private spaToken;
    address private wspaToken;
    address private rampA;

    struct Expected {
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 bufferPercent;
        uint256 exchangeRateFeeFactor;
        uint256 rateChangeSkipPeriod;
        uint256 feeErrorMargin;
        uint256 yieldErrorMargin;
        uint256 decayPeriod;
        string tokenSymbol;
    }

    Expected private exp;

    function run() external {
        _setUp();
        _verify();
        console.log("Deployment configuration match expected values");
    }

    function _setUp() internal {
        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");
        // addresses
        string memory aJson = vm.readFile(path);
        spa = aJson.readAddress(".wSwOSPool");
        factoryImplementation = aJson.readAddress(".FactoryImplementation");
        selfPeggingAssetBeacon = aJson.readAddress(".SelfPeggingAssetBeacon");
        spaTokenBeacon = aJson.readAddress(".SPATokenBeacon");
        wspaTokenBeacon = aJson.readAddress(".WSPATokenBeacon");
        rampAControllerBeacon = aJson.readAddress(".RampAControllerBeacon");
        keeperImplementation = aJson.readAddress(".KeeperImplementation");
        factory = SelfPeggingAssetFactory(aJson.readAddress(".Factory"));
        spaToken = aJson.readAddress(".wSwOSPoolSPAToken");
        wspaToken = aJson.readAddress(".wSwOSPoolWSPAToken");
        rampA = aJson.readAddress(".wSwOSRampAController");
        keeper = aJson.readAddress(".wSwOSKeeper");

        require(readImpl(address(factory)) == factoryImplementation, "mismatch factory implementation");
        require(
            readInitialized(address(factory)) > 0
                && SelfPeggingAssetFactory(factoryImplementation).proxiableUUID() == implSlot,
            "factory not initialized"
        );

        require(readBeaconProxyImpl(spaToken) == readBeaconImpl(spaTokenBeacon), "mismatch spa token implementation");
        require(readInitialized(spaToken) > 0, "spa token not initialized");
        require(readProxyBeacon(spaToken) == spaTokenBeacon, "mismatch spa token beacon");

        require(readBeaconProxyImpl(wspaToken) == readBeaconImpl(wspaTokenBeacon), "mismatch wspa token implementation");
        require(readInitialized(wspaToken) > 0, "wspa token not initialized");
        require(readProxyBeacon(wspaToken) == wspaTokenBeacon, "mismatch wspa token beacon");

        require(readBeaconProxyImpl(spa) == readBeaconImpl(selfPeggingAssetBeacon), "mismatch spa pool implementation");
        require(readInitialized(spa) > 0, "spa pool token not initialized");
        require(readProxyBeacon(spa) == selfPeggingAssetBeacon, "mismatch spa pool beacon");

        require(
            readBeaconProxyImpl(rampA) == readBeaconImpl(rampAControllerBeacon),
            "mismatch ramp a controller implementation"
        );
        require(readInitialized(rampA) > 0, "ramp a controller not initialized");
        require(readProxyBeacon(rampA) == rampAControllerBeacon, "mismatch ramp a controller beacon");

        require(readImpl(keeper) == keeperImplementation, "mismatch keeper implementation");
        require(
            readInitialized(keeper) > 0 && SelfPeggingAssetFactory(keeperImplementation).proxiableUUID() == implSlot,
            "keeper not initialized"
        );
        // expected
        string memory eJson = vm.readFile("script/configs/expected.json");
        exp.mintFee = eJson.readUint(".mintFee");
        exp.swapFee = eJson.readUint(".swapFee");
        exp.redeemFee = eJson.readUint(".redeemFee");
        exp.offPegFeeMultiplier = eJson.readUint(".offPegFeeMultiplier");
        exp.A = eJson.readUint(".A");
        exp.minRampTime = eJson.readUint(".minRampTime");
        exp.bufferPercent = eJson.readUint(".bufferPercent");
        exp.exchangeRateFeeFactor = eJson.readUint(".exchangeRateFeeFactor");
        exp.rateChangeSkipPeriod = eJson.readUint(".rateChangeSkipPeriod");
        exp.feeErrorMargin = eJson.readUint(".feeErrorMargin");
        exp.yieldErrorMargin = eJson.readUint(".yieldErrorMargin");
        exp.decayPeriod = eJson.readUint(".decayPeriod");
        exp.tokenSymbol = eJson.readString(".tokenSymbol");
    }

    function _verify() internal {
        // SPA pool
        SelfPeggingAsset pool = SelfPeggingAsset(spa);
        _eq(pool.mintFee(), exp.mintFee, "mintFee");
        _eq(pool.swapFee(), exp.swapFee, "swapFee");
        _eq(pool.redeemFee(), exp.redeemFee, "redeemFee");
        _eq(pool.offPegFeeMultiplier(), exp.offPegFeeMultiplier, "offPegFeeMultiplier");
        _eq(pool.exchangeRateFeeFactor(), exp.exchangeRateFeeFactor, "exchangeRateFeeFactor");
        _eq(pool.rateChangeSkipPeriod(), exp.rateChangeSkipPeriod, "rateChangeSkipPeriod");
        _eq(pool.feeErrorMargin(), exp.feeErrorMargin, "feeErrorMargin");
        _eq(pool.yieldErrorMargin(), exp.yieldErrorMargin, "yieldErrorMargin");
        _eq(pool.decayPeriod(), exp.decayPeriod, "decayPeriod");

        // SPAToken
        SPAToken lp = SPAToken(spaToken);
        _eq(lp.bufferPercent(), exp.bufferPercent, "bufferPercent");
        _eq(lp.symbol(), exp.tokenSymbol, "tokenSymbol");

        // RampAController
        _eq(IRampAController(rampA).getA(), exp.A, "A (amp coeff)");
        _eq(IRampAController(rampA).minRampTime(), exp.minRampTime, "minRampTime");

        // Keeper
        _eq(Keeper(keeper).treasury(), factory.governor(), "treasury");
    }

    function readInitialized(address proxy) internal view returns (uint64) {
        return uint64(uint256(vm.load(proxy, initializedSlot)));
    }

    function readImpl(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, implSlot))));
    }

    function readBeaconProxyImpl(address proxy) internal view returns (address) {
        bytes memory code = address(proxy).code;
        bytes32 result;
        // offset to get immutable variable of deployed bytecode (beacon address) is 0x18 or bytes24
        assembly {
            result := mload(add(code, add(0x20, 0x18)))
        }
        return address(uint160(uint256(vm.load(address(uint160(uint256(result))), bytes32(uint256(1))))));
    }

    function readProxyBeacon(address proxy) internal view returns (address) {
        bytes memory code = address(proxy).code;
        bytes32 result;
        // offset to get immutable variable of deployed bytecode (beacon address) is 0x18 or bytes24
        assembly {
            result := mload(add(code, add(0x20, 0x18)))
        }
        return address(uint160(uint256(result)));
    }

    function readBeaconImpl(address beacon) internal view returns (address) {
        return address(uint160(uint256(vm.load(beacon, bytes32(uint256(1))))));
    }

    function _eq(uint256 actual, uint256 expected, string memory name) private pure {
        require(actual == expected, _err(name, expected, actual));
    }

    function _eq(string memory a, string memory b, string memory name) private pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), _err(name, b, a));
    }

    function _eq(address a, address b, string memory name) private pure {
        require(a == b, _err(name, b, a));
    }

    function _err(string memory name, uint256 expVal, uint256 actVal) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", _toString(expVal), ", got ", _toString(actVal)));
    }

    function _err(string memory name, address a, address b) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", b, ", got ", a));
    }

    function _err(string memory name, string memory a, string memory b) private pure returns (string memory) {
        return string(abi.encodePacked(name, " mismatch - expected ", b, ", got ", a));
    }

    function _toString(uint256 value) private pure returns (string memory str) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        str = string(buffer);
    }
}
