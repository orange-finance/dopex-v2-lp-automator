// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase */

import {BaseFixture} from "./BaseFixture.t.sol";
import {IERC20} from "@openzeppelin/contracts//interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract WETH_USDC_Fixture is BaseFixture {
    IERC20 public constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IUniswapV3Pool public pool = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);
}
