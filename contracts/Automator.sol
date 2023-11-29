// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandler} from "./vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract Automator {
    IUniswapV3SingleTickLiquidityHandler public immutable handler;
    IUniswapV3Pool public immutable pool;

    constructor(IUniswapV3SingleTickLiquidityHandler handler_, IUniswapV3Pool pool_) {
        handler = handler_;
        pool = pool_;
    }

    function connect() public view returns (uint256, uint256) {
        (, uint256[] memory _amounts) = handler.tokensToPullForMint(
            abi.encode(
                IUniswapV3SingleTickLiquidityHandler.MintPositionParams({
                    pool: address(pool),
                    tickLower: -200700,
                    tickUpper: -200690,
                    liquidity: 100000
                })
            )
        );

        return (_amounts[0], _amounts[1]);
    }
}
