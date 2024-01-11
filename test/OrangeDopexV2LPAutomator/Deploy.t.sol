// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {OrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract TestOrangeDopexV2LPAutomatorDeploy is Test {
    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IDopexV2PositionManager constant DOPEX_POSITION_MANAGER =
        IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    IUniswapV3SingleTickLiquidityHandler constant UNIV3_HANDLER =
        IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);
    IUniswapV3Pool constant WETH_USDCE = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("arb", 157066571);
    }

    function test_deploy_revertUnsupportedAssetsDecimals() public {
        vm.mockCall(address(WETH), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomator.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomator({
            name: "OrangeDopexV2LPAutomator",
            symbol: "ODV2LP",
            admin: address(this),
            manager_: DOPEX_POSITION_MANAGER,
            handler_: UNIV3_HANDLER,
            router_: ROUTER,
            pool_: WETH_USDCE,
            asset_: WETH,
            minDepositAssets_: 0.01 ether
        });
    }

    function test_deploy_revertUnsupportedCounterAssetsDecimals() public {
        vm.mockCall(address(USDCE), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomator.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomator({
            name: "OrangeDopexV2LPAutomator",
            symbol: "ODV2LP",
            admin: address(this),
            manager_: DOPEX_POSITION_MANAGER,
            handler_: UNIV3_HANDLER,
            router_: ROUTER,
            pool_: WETH_USDCE,
            asset_: WETH,
            minDepositAssets_: 0.01 ether
        });
    }
}
