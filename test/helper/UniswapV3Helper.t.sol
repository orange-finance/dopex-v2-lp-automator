// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

struct Constants {
    IDopexV2PositionManager manager;
    address managerOwner;
    IUniswapV3SingleTickLiquidityHandlerV2 uniV3Handler;
}

library UniswapV3Helper {
    using TickMath for int24;

    function currentTick(IUniswapV3Pool pool) internal view returns (int24) {
        (, int24 tick, , , , , ) = pool.slot0();
        return tick;
    }

    function currentLower(IUniswapV3Pool pool) internal view returns (int24) {
        (, int24 _ct, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        // current lower tick is calculated by rounding down the current tick to the nearest tick spacing
        // if current tick is negative and not divisible by tick spacing, we need to subtract one tick spacing to get the correct lower tick
        int24 _currentLt = _ct < 0 && _ct % _spacing != 0
            ? (_ct / _spacing - 1) * _spacing
            : (_ct / _spacing) * _spacing;

        return _currentLt;
    }

    function singleTickLiq(
        IUniswapV3Pool pool,
        int24 tickCurrent,
        int24 tickLower,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
                tickCurrent.getSqrtRatioAtTick(),
                tickLower.getSqrtRatioAtTick(),
                (tickLower + pool.tickSpacing()).getSqrtRatioAtTick(),
                amount0,
                amount1
            );
    }

    function singleLiqLeft(IUniswapV3Pool pool, int24 tickLower, uint256 amount1) internal view returns (uint128) {
        int24 spacing = pool.tickSpacing();
        uint160 sqrtRatioAX96 = tickLower.getSqrtRatioAtTick();
        uint160 sqrtRatioBX96 = (tickLower + spacing).getSqrtRatioAtTick();

        return LiquidityAmounts.getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
    }

    function singleLiqRight(IUniswapV3Pool pool, int24 tickLower, uint256 amount0) internal view returns (uint128) {
        int24 spacing = pool.tickSpacing();
        uint160 sqrtRatioAX96 = tickLower.getSqrtRatioAtTick();
        uint160 sqrtRatioBX96 = (tickLower + spacing).getSqrtRatioAtTick();

        return LiquidityAmounts.getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
    }

    function getLiquidityForAmounts(
        IUniswapV3Pool,
        int24 tickCurrent,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
                tickCurrent.getSqrtRatioAtTick(),
                tickLower.getSqrtRatioAtTick(),
                tickUpper.getSqrtRatioAtTick(),
                amount0,
                amount1
            );
    }

    function getQuote(
        IUniswapV3Pool pool,
        address base,
        address quote,
        uint128 baseAmount
    ) internal view returns (uint256) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(_currentTick, baseAmount, base, quote);
    }

    function getAmount0ForSingleTickLiq(
        IUniswapV3Pool pool,
        int24 tickCurrent,
        int24 tickLower,
        uint128 liquidity
    ) internal view returns (uint256 amount0) {
        (amount0, ) = LiquidityAmounts.getAmountsForLiquidity(
            tickCurrent.getSqrtRatioAtTick(),
            tickLower.getSqrtRatioAtTick(),
            (tickLower + pool.tickSpacing()).getSqrtRatioAtTick(),
            liquidity
        );
    }

    function getAmount1ForSingleTickLiq(
        IUniswapV3Pool pool,
        int24 tickCurrent,
        int24 tickLower,
        uint128 liquidity
    ) internal view returns (uint256 amount1) {
        (, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            tickCurrent.getSqrtRatioAtTick(),
            tickLower.getSqrtRatioAtTick(),
            (tickLower + pool.tickSpacing()).getSqrtRatioAtTick(),
            liquidity
        );
    }

    function exactInputSingleSwap(
        ISwapRouter router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) internal returns (uint256) {
        return
            router.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp + 1,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                })
            );
    }
}
