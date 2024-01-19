// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {AutomatorUniswapV3PoolLib} from "../../contracts/lib/AutomatorUniswapV3PoolLib.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IOrangeDopexV2LPAutomator} from "../../contracts/interfaces/IOrangeDopexV2LPAutomator.sol";

contract TestUniswapV3PoolLib is Test {
    IUniswapV3Pool wethUsdce = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);

    function setUp() public {
        vm.createSelectFork("arb", 157066571);
        vm.label(address(wethUsdce), "wethUsdce");

        (, int24 tick, , , , , ) = wethUsdce.slot0();

        emit log_named_int("current tick", tick);
    }

    function test_currentTick() public {
        (, int24 tickFromSlot, , , , , ) = wethUsdce.slot0();
        int24 tick = AutomatorUniswapV3PoolLib.currentTick(wethUsdce);

        assertEq(tick, tickFromSlot, "get current tick");
    }

    function test_estimateTotalTokensFromPositions() public {
        /*/////////////////////////////////////////////////////////////
                            case: single mint
        /////////////////////////////////////////////////////////////*/

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory mintParams = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        mintParams[0].tick = -199310;
        mintParams[0].liquidity = 1e18;

        uint256 _expectedAmount0Above;
        uint256 _expectedAmount1Above;

        (uint160 _sqrtPriceX96, , , , , , ) = wethUsdce.slot0();

        (_expectedAmount0Above, _expectedAmount1Above) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(mintParams[0].tick),
            TickMath.getSqrtRatioAtTick(mintParams[0].tick + wethUsdce.tickSpacing()),
            1e18
        );

        (uint256 totalAmount0, uint256 totalAmount1) = AutomatorUniswapV3PoolLib.estimateTotalTokensFromPositions(
            wethUsdce,
            mintParams
        );

        emit log_named_uint("single mint total amount0", totalAmount0);
        emit log_named_uint("single mint total amount1", totalAmount1);

        assertEq(totalAmount0, _expectedAmount0Above, "get total amount0");
        assertEq(totalAmount1, _expectedAmount1Above, "get total amount1");
        assertEq(totalAmount1, 0, "out of range above needs no amount1");

        /*/////////////////////////////////////////////////////////////
                            case: multiple mint
        /////////////////////////////////////////////////////////////*/

        mintParams = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        mintParams[0].tick = -199310;
        mintParams[0].liquidity = 1e18;

        mintParams[1].tick = -199360;
        mintParams[1].liquidity = 2e18;

        uint256 _expectedAmount0Below;
        uint256 _expectedAmount1Below;

        (_expectedAmount0Above, _expectedAmount1Above) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(mintParams[0].tick),
            TickMath.getSqrtRatioAtTick(mintParams[0].tick + wethUsdce.tickSpacing()),
            1e18
        );

        (_expectedAmount0Below, _expectedAmount1Below) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(mintParams[1].tick),
            TickMath.getSqrtRatioAtTick(mintParams[1].tick + wethUsdce.tickSpacing()),
            2e18
        );

        (totalAmount0, totalAmount1) = AutomatorUniswapV3PoolLib.estimateTotalTokensFromPositions(
            wethUsdce,
            mintParams
        );

        emit log_named_uint("multiple mint total amount0", totalAmount0);
        emit log_named_uint("multiple mint total amount1", totalAmount1);

        assertEq(totalAmount0, _expectedAmount0Above + _expectedAmount0Below, "get total amount0");
        assertEq(totalAmount1, _expectedAmount1Above + _expectedAmount1Below, "get total amount1");
    }
}
