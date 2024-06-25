// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IUniswapV3PoolState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolState.sol";
import {IUniswapV3PoolImmutables} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";
import {IUniswapV3PoolDerivedState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";

interface IUniswapV3PoolAdapter is IUniswapV3PoolState, IUniswapV3PoolImmutables, IUniswapV3PoolDerivedState {
    /**
     * @dev Returns the address of actual amm contract (e.g. UniswapV3, PancakeV3...)
     * @return pool The address of the amm contract.
     */
    function pool() external view returns (address);
}
