// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

library UniswapV3PoolLib {
    function currentTick(IUniswapV3Pool pool) internal view returns (int24 tick) {
        (, tick, , , , , ) = pool.slot0();
    }
}
