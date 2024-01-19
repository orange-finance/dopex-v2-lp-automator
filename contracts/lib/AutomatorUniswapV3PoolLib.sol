// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IOrangeDopexV2LPAutomator} from "../interfaces/IOrangeDopexV2LPAutomator.sol";

/**
 * @title AutomatorUniswapV3PoolLib
 * @dev Library for interacting with Uniswap V3 pools in the Automator contract.
 * @author Orange Finance
 */
library AutomatorUniswapV3PoolLib {
    error BurnLiquidityExceedsMint();

    function currentTick(IUniswapV3Pool pool) internal view returns (int24 tick) {
        (, tick, , , , , ) = pool.slot0();
    }

    /**
     * @dev Estimates the total amount of tokens from a given set of positions in a Uniswap V3 pool.
     * @param pool The Uniswap V3 pool contract.
     * @param positions An array of RebalanceTickInfo structs representing the positions.
     * @return totalAmount0 The total amount of token0.
     * @return totalAmount1 The total amount of token1.
     */
    function estimateTotalTokensFromPositions(
        IUniswapV3Pool pool,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory positions
    ) internal view returns (uint256 totalAmount0, uint256 totalAmount1) {
        uint256 _a0;
        uint256 _a1;

        (, int24 _ct, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        uint256 _pLen = positions.length;
        for (uint256 i = 0; i < _pLen; i++) {
            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(_ct),
                TickMath.getSqrtRatioAtTick(positions[i].tick),
                TickMath.getSqrtRatioAtTick(positions[i].tick + _spacing),
                positions[i].liquidity
            );

            totalAmount0 += _a0;
            totalAmount1 += _a1;
        }
    }
}
