// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable const-name-snakecase */

import {OrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/OrangeStrykeLPAutomatorV1_1.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts//proxy/ERC1967/ERC1967Proxy.sol";
import {Vm} from "forge-std/Vm.sol";
import {ChainlinkQuoter} from "contracts/ChainlinkQuoter.sol";
import {IDopexV2PositionManager} from "contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts//interfaces/IERC20.sol";

Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

contract AutomatorHarness is OrangeStrykeLPAutomatorV1_1 {
    function pushActiveTick(int24 tick) external {
        EnumerableSet.add(_activeTicks, uint256(uint24(tick)));
    }
}

struct DeployArgs {
    string name;
    string symbol;
    address dopexV2ManagerOwner;
    address admin;
    address strategist;
    ChainlinkQuoter quoter;
    address assetUsdFeed;
    address counterAssetUsdFeed;
    IDopexV2PositionManager manager;
    ISwapRouter router;
    IUniswapV3SingleTickLiquidityHandlerV2 handler;
    address handlerHook;
    IUniswapV3Pool pool;
    IERC20 asset;
    uint256 minDepositAssets;
    uint256 depositCap;
}

function deployAutomatorHarness(DeployArgs memory args) returns (AutomatorHarness harness) {
    address impl = address(new AutomatorHarness());
    bytes memory initCall = abi.encodeCall(
        OrangeStrykeLPAutomatorV1_1.initialize,
        OrangeStrykeLPAutomatorV1_1.InitArgs({
            name: args.name,
            symbol: args.symbol,
            admin: args.admin,
            manager: args.manager,
            handler: args.handler,
            handlerHook: args.handlerHook,
            router: args.router,
            pool: args.pool,
            asset: args.asset,
            quoter: args.quoter,
            assetUsdFeed: args.assetUsdFeed,
            counterAssetUsdFeed: args.counterAssetUsdFeed,
            minDepositAssets: args.minDepositAssets
        })
    );

    address proxy = address(new ERC1967Proxy(impl, initCall));

    harness = AutomatorHarness(proxy);

    vm.startPrank(args.admin);
    harness.setDepositCap(args.depositCap);
    harness.setStrategist(args.strategist, true);
    harness.quoter().setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
    harness.quoter().setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);
    vm.stopPrank();

    vm.prank(args.dopexV2ManagerOwner);
    args.manager.updateWhitelistHandlerWithApp(address(args.handler), address(args.admin), true);
}
