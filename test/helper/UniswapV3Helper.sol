// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {LiquidityAmounts} from "../../contracts/vendor/uniswapV3/LiquidityAmounts.sol";
import {TickMath} from "../../contracts/vendor/uniswapV3/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

struct Constants {
    IDopexV2PositionManager manager;
    address managerOwner;
    IUniswapV3SingleTickLiquidityHandler uniV3Handler;
}

library UniswapV3Helper {
    using TickMath for int24;

    function currentTick(IUniswapV3Pool pool) internal view returns (int24) {
        (, int24 tick, , , , , ) = pool.slot0();
        return tick;
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
