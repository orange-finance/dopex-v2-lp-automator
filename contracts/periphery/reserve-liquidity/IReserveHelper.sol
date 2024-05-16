// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

interface IReserveHelper {
    function batchReserveLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] calldata reserveLiquidityParam
    ) external returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reservedPositions);
}
