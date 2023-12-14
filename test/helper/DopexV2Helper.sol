// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {IAutomator} from "../../contracts/Automator.sol";
import {LiquidityAmounts} from "../../contracts/vendor/uniswapV3/LiquidityAmounts.sol";
import {TickMath} from "../../contracts/vendor/uniswapV3/TickMath.sol";

struct Constants {
    IDopexV2PositionManager manager;
    address managerOwner;
    IUniswapV3SingleTickLiquidityHandler uniV3Handler;
}

library DopexV2Helper {
    using TickMath for int24;

    IDopexV2PositionManager constant DOPEX_V2_POSITION_MANAGER =
        IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);

    address constant DOPEX_V2_MANAGER_OWNER = 0xEE82496D3ed1f5AFbEB9B29f3f59289fd899d9D0;

    IUniswapV3SingleTickLiquidityHandler constant uniV3Handler =
        IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);
}
