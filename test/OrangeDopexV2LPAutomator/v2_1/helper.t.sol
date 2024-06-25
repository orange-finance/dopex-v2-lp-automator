// SPDX-License-Identifier: GPL-3.0

// solhint-disable-next-line one-contract-per-file
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase */
import {IOrangeStrykeLPAutomatorV2_1} from "../../../contracts/v2_1/IOrangeStrykeLPAutomatorV2_1.sol";
import {Test, Vm} from "forge-std/Test.sol";

Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

// ! The order of the struct must be the following because vm.parseJson parse a json object in alphabetical order
// ! so "liquidity" must come before "tick"
struct RawRebalanceTick {
    bytes liquidity;
    int256 tick;
}

function parseTicks(string memory ticks) pure returns (IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory) {
    // bytes memory parsedTicks = vm.parseJson(ticks, ".ticks");
    bytes memory parsedTicks = vm.parseJson(ticks, ".");
    RawRebalanceTick[] memory rawTicks = abi.decode(parsedTicks, (RawRebalanceTick[]));
    return rawToConvertedRebalanceTicks(rawTicks);
}

function rawToConvertedRebalanceTicks(
    RawRebalanceTick[] memory raw
) pure returns (IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory) {
    IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory converted = new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](
        raw.length
    );
    for (uint256 i = 0; i < raw.length; i++) {
        converted[i] = rawToConvertedRebalanceTick(raw[i]);
    }
    return converted;
}

function rawToConvertedRebalanceTick(
    RawRebalanceTick memory raw
) pure returns (IOrangeStrykeLPAutomatorV2_1.RebalanceTick memory) {
    return
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick({
            // tick: int24(uint24(raw.tick)),
            // tick: int24(uint24(_bytesToUint(raw.tick))),
            tick: int24(raw.tick),
            liquidity: uint128(_bytesToUint(raw.liquidity))
        });
}

function _bytesToUint(bytes memory b) pure returns (uint256) {
    // solhint-disable-next-line reason-string, custom-errors
    require(b.length <= 32, "StdCheats _bytesToUint(bytes): Bytes length exceeds 32.");
    return abi.decode(abi.encodePacked(new bytes(32 - b.length), b), (uint256));
}

contract TestOrangeStrykeLPAutomatorV2_1Helper is Test {
    function test_parseRebalanceTicksJson() public pure {
        // solhint-disable-next-line quotes
        string memory ticks = '[{"tick": -887220, "liquidity": "0x5f5e100"}, {"tick": -887200, "liquidity": "0x5f5e100"}]'; // prettier-ignore
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory rebalanceTicks = parseTicks(ticks);

        assertEq(rebalanceTicks.length, 2);
        assertEq(rebalanceTicks[0].tick, -887220);
        assertEq(rebalanceTicks[0].liquidity, 0x5f5e100);
        assertEq(rebalanceTicks[1].tick, -887200);
        assertEq(rebalanceTicks[1].liquidity, 0x5f5e100);
    }

    function test_parseRebalanceTicksJson_empty() public pure {
        // solhint-disable-next-line quotes
        string memory ticks = "[]";
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory rebalanceTicks = parseTicks(ticks);

        assertEq(rebalanceTicks.length, 0);
    }
}
