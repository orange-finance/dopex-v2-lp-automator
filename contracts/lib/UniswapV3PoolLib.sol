// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title AutomatorUniswapV3PoolLib
 * @dev Library for interacting with Uniswap V3 pools in the Automator contract.
 * @author Orange Finance
 */
library UniswapV3PoolLib {
    error BurnLiquidityExceedsMint();

    function currentTick(IUniswapV3Pool pool) internal view returns (int24 tick) {
        (, tick, , , , , ) = pool.slot0();
    }
}
