// SPDX-License-Identifier: GPL-3.0

// solhint-disable one-contract-per-file, custom-errors
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
import {StrykeVaultInspector} from "../../../contracts/periphery/StrykeVaultInspector.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {parseTicks} from "./helper.t.sol";

contract OrangeStrykeLPAutomatorV2Handler is Test {
    OrangeStrykeLPAutomatorV2 public automator;
    StrykeVaultInspector public inspector;
    ISwapRouter public swapRouter;
    address public automatorOwner;
    address public strategist;
    address public kyberswapProxy;
    address public mockSwapProxy;

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
        address kyberswapProxy;
        address mockSwapProxy;
        StrykeVaultInspector inspector;
        ISwapRouter swapRouter;
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 maxAmountIn;
        uint256 amountOut;
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
        inspector = new StrykeVaultInspector();
        swapRouter = args.swapRouter;
        kyberswapProxy = args.kyberswapProxy;
        mockSwapProxy = args.mockSwapProxy;

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

        vm.startPrank(args.admin);
        automator.setProxyWhitelist(args.kyberswapProxy, true);
        automator.setProxyWhitelist(args.mockSwapProxy, true);
        vm.stopPrank();
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
        if (redeemData.length != 0) {
            (address swapProxy, , ) = abi.decode(redeemData, (address, address, bytes));
            vm.prank(automatorOwner);
            automator.setProxyWhitelist(swapProxy, true);
        }

        vm.prank(redeemer);
        automator.redeem(shares, redeemData);
    }

    function redeemWithMockSwap(uint256 shares, address redeemer) external {
        (uint256 token0, uint256 token1) = inspector.convertSharesToPairAssets(automator, shares);
        uint256 tokenIn;

        if (automator.pool().token0() == address(automator.asset())) {
            tokenIn = token1;
        } else {
            tokenIn = token0;
        }

        bytes memory uniswapCalldata = abi.encodeWithSelector(
            ISwapRouter.exactInputSingle.selector,
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(automator.counterAsset()),
                tokenOut: address(automator.asset()),
                fee: automator.pool().fee(),
                recipient: address(automator),
                deadline: block.timestamp + 300,
                amountIn: tokenIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        bytes memory redeemData = abi.encode(mockSwapProxy, swapRouter, uniswapCalldata);

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
            TickMath.getSqrtRatioAtTick(lowerTick + automator.poolTickSpacing()),
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

    function rebalanceWithMockSwap(
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory mintTicks,
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory burnTicks
    ) external {
        SwapParams memory swapParams = calculateSwapParamsInRebalance(mintTicks, burnTicks);

        ISwapRouter.ExactInputSingleParams memory exactSingle = ISwapRouter.ExactInputSingleParams({
            tokenIn: swapParams.tokenIn,
            tokenOut: swapParams.tokenOut,
            fee: automator.pool().fee(),
            recipient: address(automator),
            deadline: block.timestamp + 300,
            amountIn: swapParams.maxAmountIn,
            amountOutMinimum: swapParams.amountOut,
            sqrtPriceLimitX96: 0
        });

        vm.prank(strategist);
        IOrangeSwapProxy.SwapInputRequest memory swapRequest = IOrangeSwapProxy.SwapInputRequest({
            provider: address(swapRouter),
            swapCalldata: abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, exactSingle),
            expectTokenIn: IERC20(swapParams.tokenIn),
            expectTokenOut: IERC20(swapParams.tokenOut),
            expectAmountIn: swapParams.maxAmountIn,
            inputDelta: 10
        });

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = swapParams.tokenOut;
        amounts[0] = swapParams.amountOut;

        bool execFlashLoan = swapParams.maxAmountIn > 0;

        bytes memory flashLoanData = abi.encode(tokens, amounts, execFlashLoan);

        automator.rebalance(mintTicks, burnTicks, mockSwapProxy, swapRequest, flashLoanData);
    }

    function calculateSwapParamsInRebalance(
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory ticksMint,
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory ticksBurn
    ) internal view returns (SwapParams memory swapParams) {
        uint256 _mintAssets;
        uint256 _mintCAssets;
        uint256 _burnAssets;
        uint256 _burnCAssets;

        if (automator.pool().token0() == address(automator.asset())) {
            (_mintAssets, _mintCAssets) = estimateTotalTokensFromPositions(automator.pool(), ticksMint);
            (_burnAssets, _burnCAssets) = estimateTotalTokensFromPositions(automator.pool(), ticksBurn);
        } else {
            (_mintCAssets, _mintAssets) = estimateTotalTokensFromPositions(automator.pool(), ticksMint);
            (_burnCAssets, _burnAssets) = estimateTotalTokensFromPositions(automator.pool(), ticksBurn);
        }

        uint256 _freeAssets = _burnAssets + automator.asset().balanceOf(address(automator));
        uint256 _freeCAssets = _burnCAssets + automator.counterAsset().balanceOf(address(automator));

        uint256 _assetsShortage;
        if (_mintAssets > _freeAssets) _assetsShortage = _mintAssets - _freeAssets;

        uint256 _counterAssetsShortage;
        if (_mintCAssets > _freeCAssets) _counterAssetsShortage = _mintCAssets - _freeCAssets;

        if (_assetsShortage > 0 && _counterAssetsShortage > 0) revert("Liquidity too large");

        if (_assetsShortage > 0) {
            swapParams.tokenIn = address(automator.counterAsset());
            swapParams.tokenOut = address(automator.asset());
            swapParams.maxAmountIn = _freeCAssets - _mintCAssets;
            swapParams.amountOut = _assetsShortage;
        }

        if (_counterAssetsShortage > 0) {
            swapParams.tokenIn = address(automator.asset());
            swapParams.tokenOut = address(automator.counterAsset());
            swapParams.maxAmountIn = _freeAssets - _mintAssets;
            swapParams.amountOut = _counterAssetsShortage;
        }

        // we need to add buffer for price error when swapping and minting positions.
        // swap fee applied to the receiving token.
        // more counter assets will be used to mint stryke positions.
        swapParams.amountOut = FullMath.mulDiv(swapParams.amountOut, 1e6 + 5e3, 1e6);
    }

    function estimateTotalTokensFromPositions(
        IUniswapV3Pool pool,
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory positions
    ) internal view returns (uint256 totalAmount0, uint256 totalAmount1) {
        uint256 _a0;
        uint256 _a1;

        (, int24 _ct, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        uint256 _pLen = positions.length;
        for (uint256 i = 0; i < _pLen; i++) {
            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(_ct),
                TickMath.getSqrtRatioAtTick(positions[i].tick),
                TickMath.getSqrtRatioAtTick(positions[i].tick + _spacing),
                positions[i].liquidity
            );

            totalAmount0 += _a0;
            totalAmount1 += _a1;
        }
    }
}
