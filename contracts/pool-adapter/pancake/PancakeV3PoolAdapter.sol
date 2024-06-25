// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IUniswapV3PoolAdapter} from "../IUniswapV3PoolAdapter.sol";
import {IPancakeV3Pool} from "./interfaces/IPancakeV3Pool.sol";

contract PancakeV3PoolAdapter is IUniswapV3PoolAdapter {
    IPancakeV3Pool public immutable pool;

    constructor(IPancakeV3Pool _pool) {
        pool = _pool;
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        // PancakeV3 Pool has uint32 feeProtocol, but UniswapV3PoolAdapter uses uint8
        // We set the value to zero as we don't use this value
        feeProtocol = 0;
        (sqrtPriceX96, tick, observationIndex, observationCardinality, observationCardinalityNext, , unlocked) = pool
            .slot0();
    }

    function feeGrowthGlobal0X128() external view returns (uint256) {
        return pool.feeGrowthGlobal0X128();
    }

    function feeGrowthGlobal1X128() external view returns (uint256) {
        return pool.feeGrowthGlobal1X128();
    }

    function protocolFees() external view returns (uint128 _token0, uint128 _token1) {
        return pool.protocolFees();
    }

    // @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128) {
        return pool.liquidity();
    }

    function ticks(
        int24 tick
    )
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        )
    {
        return pool.ticks(tick);
    }

    function tickBitmap(int16 wordPosition) external view returns (uint256) {
        return pool.tickBitmap(wordPosition);
    }

    function positions(
        bytes32 key
    )
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        return pool.positions(key);
    }

    function observations(
        uint256 index
    )
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        )
    {
        return pool.observations(index);
    }

    function factory() external view returns (address) {
        return pool.factory();
    }

    function token0() external view returns (address) {
        return pool.token0();
    }

    function token1() external view returns (address) {
        return pool.token1();
    }

    function fee() external view returns (uint24) {
        return pool.fee();
    }

    function tickSpacing() external view returns (int24) {
        return pool.tickSpacing();
    }

    function maxLiquidityPerTick() external view returns (uint128) {
        return pool.maxLiquidityPerTick();
    }

    function observe(
        uint32[] calldata secondsAgos
    ) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        return pool.observe(secondsAgos);
    }

    function snapshotCumulativesInside(
        int24 tickLower,
        int24 tickUpper
    ) external view returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside) {
        return pool.snapshotCumulativesInside(tickLower, tickUpper);
    }
}
