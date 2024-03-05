// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase */
import {Test} from "forge-std/Test.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapV3PoolLib} from "../../../contracts/lib/UniswapV3PoolLib.sol";

contract TestUniswapV3PoolLib is Test {
    IUniswapV3Pool public wethUsdce = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);

    function setUp() public {
        vm.createSelectFork("arb", 157066571);
        vm.label(address(wethUsdce), "wethUsdce");

        (, int24 tick, , , , , ) = wethUsdce.slot0();

        emit log_named_int("current tick", tick);
    }

    function test_currentTick() public {
        (, int24 tickFromSlot, , , , , ) = wethUsdce.slot0();
        int24 tick = UniswapV3PoolLib.currentTick(wethUsdce);

        assertEq(tick, tickFromSlot, "get current tick");
    }
}
