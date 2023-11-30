// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Automator} from "../contracts/Automator.sol";

import {IUniswapV3SingleTickLiquidityHandler} from "../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract TestAutomator is Test {
    // address constant DOPEX_POSITION_MANAGER = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;
    // address constant DOPEX_UNISWAP_V3_HANDLER = 0xe11d346757d052214686bCbC860C94363AfB4a9A;
    // address constant DOPEX_OWNER = 0x2c9bC901f39F847C2fe5D2D7AC9c5888A2Ab8Fcf;

    // ISwapRouter constant UNISWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    // IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    // IUniswapV3Pool constant UNISWAP_WETH_USDCE_500 = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    // IUniswapV3SingleTickLiquidityHandler handler = IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);

    IUniswapV3Pool pool = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IUniswapV3SingleTickLiquidityHandler handler =
        IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);

    function setUp() public {
        vm.createSelectFork("arb", 151299689);

        vm.label(address(handler), "dopexHandler");
        vm.label(address(pool), "weth_usdc.e");
    }

    function test_connect() public {
        // Automator _automator = new Automator(handler, pool);
        // (uint256 _amount0, uint256 _amount1) = _automator.connect();
        // emit log_named_uint("amount0", _amount0);
        // emit log_named_uint("amount1", _amount1);
    }
}
