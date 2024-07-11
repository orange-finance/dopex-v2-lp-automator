// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {PancakeV3PoolAdapter} from "../../../contracts/pool-adapter/pancake/PancakeV3PoolAdapter.sol";
import {IPancakeV3Pool} from "../../../contracts/pool-adapter/pancake/interfaces/IPancakeV3Pool.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

contract TestPancakeV3PoolAdapter is Test {
    PancakeV3PoolAdapter public poolAdapter;
    IPancakeV3Pool public WETH_USDC = IPancakeV3Pool(0xd9e2a1a61B6E61b275cEc326465d417e52C1b95c);

    function setUp() public {
        vm.createSelectFork("arb", 225519335);
        poolAdapter = new PancakeV3PoolAdapter(WETH_USDC);
    }

    function test_slot0() public view {
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            ,
            bool unlocked
        ) = WETH_USDC.slot0();

        (
            uint160 sqrtPriceX962,
            int24 tick2,
            uint16 observationIndex2,
            uint16 observationCardinality2,
            uint16 observationCardinalityNext2,
            uint8 feeProtocol,
            bool unlocked2
        ) = poolAdapter.slot0();

        assertEq(sqrtPriceX96, sqrtPriceX962);
        assertEq(tick, tick2);
        assertEq(observationIndex, observationIndex2);
        assertEq(observationCardinality, observationCardinality2);
        assertEq(observationCardinalityNext, observationCardinalityNext2);
        assertEq(unlocked, unlocked2);
        assertEq(feeProtocol, 0);
    }

    function test_feeGrowthGlobal0X128() public view {
        uint256 feeGrowthGlobal0X128 = WETH_USDC.feeGrowthGlobal0X128();
        uint256 feeGrowthGlobal0X1282 = poolAdapter.feeGrowthGlobal0X128();
        assertEq(feeGrowthGlobal0X128, feeGrowthGlobal0X1282);
    }

    function test_feeGrowthGlobal1X128() public view {
        uint256 feeGrowthGlobal1X128 = WETH_USDC.feeGrowthGlobal1X128();
        uint256 feeGrowthGlobal1X1282 = poolAdapter.feeGrowthGlobal1X128();
        assertEq(feeGrowthGlobal1X128, feeGrowthGlobal1X1282);
    }

    function test_protocolFees() public view {
        (uint128 token0, uint128 token1) = WETH_USDC.protocolFees();
        (uint128 token02, uint128 token12) = poolAdapter.protocolFees();
        assertEq(token0, token02);
        assertEq(token1, token12);
    }

    function test_liquidity() public view {
        uint128 liquidity = WETH_USDC.liquidity();
        uint128 liquidity2 = poolAdapter.liquidity();
        assertEq(liquidity, liquidity2);
    }

    function test_ticks() public view {
        // to avoid stack too deep, we divide scope into two
        {
            (
                uint128 liquidityGross,
                int128 liquidityNet,
                uint256 feeGrowthOutside0X128,
                uint256 feeGrowthOutside1X128,
                ,
                ,
                ,

            ) = WETH_USDC.ticks(-195124);

            (
                uint128 liquidityGross2,
                int128 liquidityNet2,
                uint256 feeGrowthOutside0X1282,
                uint256 feeGrowthOutside1X1282,
                ,
                ,
                ,

            ) = poolAdapter.ticks(-195124);

            assertEq(liquidityGross, liquidityGross2);
            assertEq(liquidityNet, liquidityNet2);
            assertEq(feeGrowthOutside0X128, feeGrowthOutside0X1282);
            assertEq(feeGrowthOutside1X128, feeGrowthOutside1X1282);
        }

        {
            (
                ,
                ,
                ,
                ,
                int56 tickCumulativeOutside,
                uint160 secondsPerLiquidityOutsideX128,
                uint32 secondsOutside,
                bool initialized
            ) = WETH_USDC.ticks(195124);

            (
                ,
                ,
                ,
                ,
                int56 tickCumulativeOutside2,
                uint160 secondsPerLiquidityOutsideX1282,
                uint32 secondsOutside2,
                bool initialized2
            ) = poolAdapter.ticks(195124);

            assertEq(tickCumulativeOutside, tickCumulativeOutside2);
            assertEq(secondsPerLiquidityOutsideX128, secondsPerLiquidityOutsideX1282);
            assertEq(secondsOutside, secondsOutside2);
            assertEq(initialized, initialized2);
        }
    }

    function test_tickBitmap() public view {
        uint256 tickBitmap = WETH_USDC.tickBitmap(1000);
        uint256 tickBitmap2 = poolAdapter.tickBitmap(1000);
        assertEq(tickBitmap, tickBitmap2);
    }

    function test_positions() public view {
        bytes32 key = PositionKey.compute(0x9ae336B61D7d2e19a47607f163A3fB0e46306b7b, -194210, -194200);

        (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = WETH_USDC.positions(key);

        (
            uint128 _liquidity2,
            uint256 feeGrowthInside0LastX1282,
            uint256 feeGrowthInside1LastX1282,
            uint128 tokensOwed02,
            uint128 tokensOwed12
        ) = poolAdapter.positions(key);

        assertEq(_liquidity, _liquidity2);
        assertEq(feeGrowthInside0LastX128, feeGrowthInside0LastX1282);
        assertEq(feeGrowthInside1LastX128, feeGrowthInside1LastX1282);
        assertEq(tokensOwed0, tokensOwed02);
        assertEq(tokensOwed1, tokensOwed12);
    }

    function test_observations() public view {
        (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        ) = WETH_USDC.observations(1);
        (
            uint32 blockTimestamp2,
            int56 tickCumulative2,
            uint160 secondsPerLiquidityCumulativeX1282,
            bool initialized2
        ) = poolAdapter.observations(1);

        assertEq(blockTimestamp, blockTimestamp2);
        assertEq(tickCumulative, tickCumulative2);
        assertEq(secondsPerLiquidityCumulativeX128, secondsPerLiquidityCumulativeX1282);
        assertEq(initialized, initialized2);
    }

    function test_factory() public view {
        address factory = WETH_USDC.factory();
        address factory2 = poolAdapter.factory();
        assertEq(factory, factory2);
    }

    function test_token0() public view {
        address token0 = WETH_USDC.token0();
        address token02 = poolAdapter.token0();
        assertEq(token0, token02);
    }

    function test_token1() public view {
        address token1 = WETH_USDC.token1();
        address token12 = poolAdapter.token1();
        assertEq(token1, token12);
    }

    function test_fee() public view {
        uint24 fee = WETH_USDC.fee();
        uint24 fee2 = poolAdapter.fee();
        assertEq(fee, fee2);
    }

    function test_tickSpacing() public view {
        int24 tickSpacing = WETH_USDC.tickSpacing();
        int24 tickSpacing2 = poolAdapter.tickSpacing();
        assertEq(tickSpacing, tickSpacing2);
    }

    function test_maxLiquidityPerTick() public view {
        uint160 maxLiquidityPerTick = WETH_USDC.maxLiquidityPerTick();
        uint160 maxLiquidityPerTick2 = poolAdapter.maxLiquidityPerTick();
        assertEq(maxLiquidityPerTick, maxLiquidityPerTick2);
    }

    function test_observe() public view {
        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = 600;
        secondAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = WETH_USDC.observe(
            secondAgos
        );
        (int56[] memory tickCumulatives2, uint160[] memory secondsPerLiquidityCumulativeX128s2) = poolAdapter.observe(
            secondAgos
        );
        assertEq(tickCumulatives[0], tickCumulatives2[0]);
        assertEq(tickCumulatives[1], tickCumulatives2[1]);
        assertEq(secondsPerLiquidityCumulativeX128s[0], secondsPerLiquidityCumulativeX128s2[0]);
        assertEq(secondsPerLiquidityCumulativeX128s[1], secondsPerLiquidityCumulativeX128s2[1]);
    }

    function test_snapshotCumulativesInside() public view {
        (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside) = WETH_USDC
            .snapshotCumulativesInside(-194210, -194200);
        (int56 tickCumulativeInside2, uint160 secondsPerLiquidityInsideX1282, uint32 secondsInside2) = poolAdapter
            .snapshotCumulativesInside(-194210, -194200);
        assertEq(tickCumulativeInside, tickCumulativeInside2);
        assertEq(secondsPerLiquidityInsideX128, secondsPerLiquidityInsideX1282);
        assertEq(secondsInside, secondsInside2);
    }
}
