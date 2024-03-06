// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {IDopexV2PositionManager} from "./../../../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

contract BaseFixture is Test {
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public dave = makeAddr("dave");

    // Stryke
    IUniswapV3SingleTickLiquidityHandlerV2 public handlerV2 =
        IUniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
    IDopexV2PositionManager public manager = IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    address public dopexV2OptionMarket = 0x764fA09d0B3de61EeD242099BD9352C1C61D3d27;
    address public managerOwner = 0xEE82496D3ed1f5AFbEB9B29f3f59289fd899d9D0;

    // Uniswap V3
    ISwapRouter public router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
}