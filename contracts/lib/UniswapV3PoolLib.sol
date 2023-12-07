// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "../vendor/uniswapV3/LiquidityAmounts.sol";
import {TickMath} from "../vendor/uniswapV3/TickMath.sol";

library UniswapV3PoolLib {
    function currentTick(IUniswapV3Pool pool) internal view returns (int24 tick) {
        (, tick, , , , , ) = pool.slot0();
    }

    struct MintParams {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    function estimateTotalAmountsToMint(
        IUniswapV3Pool pool,
        MintParams[] memory mintParams
    ) internal view returns (uint256 totalAmount0, uint256 totalAmount1) {
        uint256 _a0;
        uint256 _a1;

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        for (uint256 i = 0; i < mintParams.length; i++) {
            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(mintParams[i].tickLower),
                TickMath.getSqrtRatioAtTick(mintParams[i].tickUpper),
                mintParams[i].liquidity
            );

            totalAmount0 += _a0;
            totalAmount1 += _a1;
        }
    }
}
