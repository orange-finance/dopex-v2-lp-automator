// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {OrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";
import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract TestOrangeDopexV2LPAutomatorDeploy is Test {
    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IDopexV2PositionManager constant DOPEX_POSITION_MANAGER =
        IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    IUniswapV3SingleTickLiquidityHandlerV2 constant UNIV3_HANDLER =
        IUniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
    IUniswapV3Pool constant WETH_USDCE = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);
    ISwapRouter ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("arb", 157066571);
    }

    function test_deploy_revertUnsupportedAssetsDecimals() public {
        vm.mockCall(address(WETH), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomator.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: DOPEX_POSITION_MANAGER,
                handler: UNIV3_HANDLER,
                handlerHook: address(0),
                router: ROUTER,
                pool: WETH_USDCE,
                asset: WETH,
                quoter: ChainlinkQuoter(address(1)),
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );
    }

    function test_deploy_revertUnsupportedCounterAssetsDecimals() public {
        vm.mockCall(address(USDC), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomator.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: DOPEX_POSITION_MANAGER,
                handler: UNIV3_HANDLER,
                handlerHook: address(0),
                router: ROUTER,
                pool: WETH_USDCE,
                asset: WETH,
                quoter: ChainlinkQuoter(address(1)),
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );
    }
}
