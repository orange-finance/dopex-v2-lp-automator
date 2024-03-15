// SPDX-License-Identifier: GPL-3.0

// solhint-disable-next-line one-contract-per-file
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDopexV2PositionManager} from "../../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";
import {IOrangeSwapProxy} from "./../../../contracts/v2/IOrangeSwapProxy.sol";
import {OrangeStrykeLPAutomatorV2} from "../../../contracts/v2/OrangeStrykeLPAutomatorV2.sol";
import {ChainlinkQuoter} from "../../../contracts/ChainlinkQuoter.sol";
import {IBalancerVault} from "../../../contracts/vendor/balancer/IBalancerVault.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts//proxy/ERC1967/ERC1967Proxy.sol";

import {parseTicks} from "./helper.t.sol";

contract OrangeStrykeLPAutomatorV2Handler is Test {
    OrangeStrykeLPAutomatorV2 public automator;
    address public automatorOwner;
    address public strategist;

    struct InitArgs {
        string name;
        string symbol;
        address admin;
        IDopexV2PositionManager manager;
        IUniswapV3SingleTickLiquidityHandlerV2 handler;
        address handlerHook;
        IUniswapV3Pool pool;
        IERC20 asset;
        ChainlinkQuoter quoter;
        address assetUsdFeed;
        address counterAssetUsdFeed;
        uint256 minDepositAssets;
        IBalancerVault balancer;
        uint256 depositCap;
        address strategist;
        address dopexV2ManagerOwner;
        uint256 initialDeposit;
    }

    constructor(InitArgs memory args) {
        address impl = address(new OrangeStrykeLPAutomatorV2());
        bytes memory initCall = abi.encodeCall(
            OrangeStrykeLPAutomatorV2.initialize,
            OrangeStrykeLPAutomatorV2.InitArgs({
                name: args.name,
                symbol: args.symbol,
                admin: args.admin,
                manager: args.manager,
                handler: args.handler,
                handlerHook: args.handlerHook,
                pool: args.pool,
                asset: args.asset,
                quoter: args.quoter,
                assetUsdFeed: args.assetUsdFeed,
                counterAssetUsdFeed: args.counterAssetUsdFeed,
                minDepositAssets: args.minDepositAssets,
                balancer: args.balancer
            })
        );

        address proxy = address(new ERC1967Proxy(impl, initCall));

        automator = OrangeStrykeLPAutomatorV2(proxy);
        automatorOwner = args.admin;
        strategist = args.strategist;

        vm.startPrank(args.admin);
        automator.setDepositCap(args.depositCap);
        automator.setStrategist(args.strategist, true);
        automator.quoter().setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        automator.quoter().setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);
        vm.stopPrank();

        vm.prank(args.dopexV2ManagerOwner);
        args.manager.updateWhitelistHandlerWithApp(address(args.handler), address(args.admin), true);

        if (args.initialDeposit > 0) {
            deal(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, msg.sender, args.initialDeposit);
            vm.startPrank(msg.sender);
            IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(automator), args.initialDeposit);
            automator.deposit(args.initialDeposit);
            vm.stopPrank();
        }
    }

    function deposit(uint256 assets, address depositor) external returns (uint256 shares) {
        IERC20 _asset = automator.asset();
        deal(address(_asset), depositor, assets);
        vm.startPrank(depositor);
        _asset.approve(address(automator), assets);
        shares = automator.deposit(assets);
        vm.stopPrank();
    }

    function redeem(uint256 shares, bytes memory redeemData, address redeemer) external {
        (address swapProxy, , ) = abi.decode(redeemData, (address, address, bytes));
        vm.prank(automatorOwner);
        automator.setProxyWhitelist(swapProxy, true);

        vm.prank(redeemer);
        automator.redeem(shares, redeemData);
    }

    function rebalance(
        string memory ticksMint,
        string memory ticksBurn,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest memory swapRequest,
        bytes memory flashLoanData
    ) external {
        vm.prank(automatorOwner);
        automator.setProxyWhitelist(swapProxy, true);

        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory mintTicks = parseTicks(ticksMint);
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory burnTicks = parseTicks(ticksBurn);

        vm.prank(strategist);
        automator.rebalance(mintTicks, burnTicks, swapProxy, swapRequest, flashLoanData);
    }

    function rebalanceSingleLeft(int24 lowerTick, uint256 amount1) external {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(lowerTick + automator.poolTickSpacing()),
            amount1
        );

        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory mintTicks = new IOrangeStrykeLPAutomatorV2.RebalanceTick[](1);
        mintTicks[0] = IOrangeStrykeLPAutomatorV2.RebalanceTick({tick: lowerTick, liquidity: liquidity});

        vm.prank(strategist);
        automator.rebalance(
            mintTicks,
            new IOrangeStrykeLPAutomatorV2.RebalanceTick[](0),
            address(0),
            IOrangeSwapProxy.SwapInputRequest({
                provider: address(0),
                swapCalldata: new bytes(0),
                expectTokenIn: IERC20(address(0)),
                expectTokenOut: IERC20(address(0)),
                expectAmountIn: 0,
                inputDelta: 0
            }),
            abi.encode(new IERC20[](0), new uint256[](0), false)
        );
    }

    function rebalanceSingleRight(int24 lowerTick, uint256 amount0) external {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(automator.poolTickSpacing()),
            amount0
        );

        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory mintTicks = new IOrangeStrykeLPAutomatorV2.RebalanceTick[](1);
        mintTicks[0] = IOrangeStrykeLPAutomatorV2.RebalanceTick({tick: lowerTick, liquidity: liquidity});

        vm.prank(strategist);
        automator.rebalance(
            mintTicks,
            new IOrangeStrykeLPAutomatorV2.RebalanceTick[](0),
            address(0),
            IOrangeSwapProxy.SwapInputRequest({
                provider: address(0),
                swapCalldata: new bytes(0),
                expectTokenIn: IERC20(address(0)),
                expectTokenOut: IERC20(address(0)),
                expectAmountIn: 0,
                inputDelta: 0
            }),
            abi.encode(new IERC20[](0), new uint256[](0), false)
        );
    }
}
