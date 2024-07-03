// SPDX-License-Identifier: GPL-3.0

// solhint-disable one-contract-per-file, custom-errors, contract-name-camelcase, private-vars-leading-underscore, var-name-mixedcase
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDopexV2PositionManager} from "../../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IOrangeStrykeLPAutomatorV2_1} from "../../../contracts/v2_1/IOrangeStrykeLPAutomatorV2_1.sol";
import {OrangeStrykeLPAutomatorV2} from "../../../contracts/v2/OrangeStrykeLPAutomatorV2.sol";
import {IOrangeSwapProxy} from "../../../contracts/swap-proxy/IOrangeSwapProxy.sol";
import {OrangeStrykeLPAutomatorV1_1} from "../../../contracts/v1_1/OrangeStrykeLPAutomatorV1_1.sol";
import {OrangeStrykeLPAutomatorV2_1} from "../../../contracts/v2_1/OrangeStrykeLPAutomatorV2_1.sol";
import {ChainlinkQuoter} from "../../../contracts/ChainlinkQuoter.sol";
import {IBalancerVault} from "../../../contracts/vendor/balancer/IBalancerVault.sol";
import {StrykeVaultInspectorV2} from "../../../contracts/periphery/StrykeVaultInspectorV2.sol";
import {IUniswapV3PoolAdapter} from "../../../contracts/pool-adapter/IUniswapV3PoolAdapter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {parseTicks} from "./helper.t.sol";

contract OrangeStrykeLPAutomatorV2_1Handler is Test {
    OrangeStrykeLPAutomatorV2_1 public automator;
    StrykeVaultInspectorV2 public inspector;
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
        StrykeVaultInspectorV2 inspector;
        ISwapRouter swapRouter;
        IUniswapV3PoolAdapter poolAdapter;
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 maxAmountIn;
        uint256 amountOut;
    }

    constructor(InitArgs memory args) {
        address implV1 = address(new OrangeStrykeLPAutomatorV1_1());
        bytes memory v1InitCall = abi.encodeCall(
            OrangeStrykeLPAutomatorV1_1.initialize,
            OrangeStrykeLPAutomatorV1_1.InitArgs({
                name: args.name,
                symbol: args.symbol,
                admin: args.admin,
                manager: args.manager,
                handler: args.handler,
                handlerHook: args.handlerHook,
                router: args.swapRouter,
                pool: args.pool,
                asset: args.asset,
                quoter: args.quoter,
                assetUsdFeed: args.assetUsdFeed,
                counterAssetUsdFeed: args.counterAssetUsdFeed,
                minDepositAssets: args.minDepositAssets
            })
        );

        address proxy = address(new ERC1967Proxy(implV1, v1InitCall));

        vm.startPrank(args.admin);
        // upgrade to v2
        address implV2 = address(new OrangeStrykeLPAutomatorV2());
        OrangeStrykeLPAutomatorV1_1(proxy).upgradeToAndCall(
            implV2,
            abi.encodeCall(OrangeStrykeLPAutomatorV2.initializeV2, args.balancer)
        );
        // upgrade to v2.1
        address implV2_1 = address(new OrangeStrykeLPAutomatorV2_1());
        OrangeStrykeLPAutomatorV2(proxy).upgradeToAndCall(
            implV2_1,
            abi.encodeCall(OrangeStrykeLPAutomatorV2_1.initializeV2_1, args.poolAdapter)
        );
        vm.stopPrank();

        automator = OrangeStrykeLPAutomatorV2_1(proxy);
        automatorOwner = args.admin;
        strategist = args.strategist;
        inspector = new StrykeVaultInspectorV2();
        swapRouter = args.swapRouter;
        kyberswapProxy = args.kyberswapProxy;
        mockSwapProxy = args.mockSwapProxy;

        vm.startPrank(args.admin);
        automator.setDepositCap(args.depositCap);
        automator.setStrategist(args.strategist, true);
        ChainlinkQuoter(address(automator.quoter())).setStalenessThreshold(
            0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            86400
        );
        ChainlinkQuoter(address(automator.quoter())).setStalenessThreshold(
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            86400
        );
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

    function redeem(uint256 shares, uint256 minAssets, address redeemer) external {
        vm.prank(redeemer);
        automator.redeem(shares, minAssets);
    }

    function rebalance(
        string memory ticksMint,
        string memory ticksBurn,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest memory swapRequest,
        bytes memory flashLoanData
    ) external {
        if (automator.asset().allowance(address(automator), swapProxy) == 0) {
            vm.prank(automatorOwner);
            automator.setProxyWhitelist(swapProxy, true);
        }

        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory mintTicks = parseTicks(ticksMint);
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory burnTicks = parseTicks(ticksBurn);

        vm.prank(strategist);
        automator.rebalance(mintTicks, burnTicks, swapProxy, swapRequest, flashLoanData);
    }

    function rebalanceSingleLeft(int24 lowerTick, uint256 amount1) external {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(lowerTick + automator.poolTickSpacing()),
            amount1
        );

        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[]
            memory mintTicks = new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](1);
        mintTicks[0] = IOrangeStrykeLPAutomatorV2_1.RebalanceTick({tick: lowerTick, liquidity: liquidity});

        vm.prank(strategist);
        automator.rebalance(
            mintTicks,
            new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](0),
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

        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[]
            memory mintTicks = new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](1);
        mintTicks[0] = IOrangeStrykeLPAutomatorV2_1.RebalanceTick({tick: lowerTick, liquidity: liquidity});

        vm.prank(strategist);
        automator.rebalance(
            mintTicks,
            new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](0),
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
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory mintTicks,
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory burnTicks
    ) external {
        SwapParams memory swapParams = calculateSwapParamsInRebalance(mintTicks, burnTicks);

        ISwapRouter.ExactInputSingleParams memory exactSingle = ISwapRouter.ExactInputSingleParams({
            tokenIn: swapParams.tokenIn,
            tokenOut: swapParams.tokenOut,
            fee: automator.poolAdapter().fee(),
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
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory ticksMint,
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory ticksBurn
    ) internal view returns (SwapParams memory swapParams) {
        uint256 _mintAssets;
        uint256 _mintCAssets;
        uint256 _burnAssets;
        uint256 _burnCAssets;

        if (automator.poolAdapter().token0() == address(automator.asset())) {
            (_mintAssets, _mintCAssets) = estimateTotalTokensFromPositions(automator.poolAdapter(), ticksMint);
            (_burnAssets, _burnCAssets) = estimateTotalTokensFromPositions(automator.poolAdapter(), ticksBurn);
        } else {
            (_mintCAssets, _mintAssets) = estimateTotalTokensFromPositions(automator.poolAdapter(), ticksMint);
            (_burnCAssets, _burnAssets) = estimateTotalTokensFromPositions(automator.poolAdapter(), ticksBurn);
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
        IUniswapV3PoolAdapter poolAdapter,
        IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory positions
    ) internal view returns (uint256 totalAmount0, uint256 totalAmount1) {
        uint256 _a0;
        uint256 _a1;

        (, int24 _ct, , , , , ) = poolAdapter.slot0();
        int24 _spacing = poolAdapter.tickSpacing();

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
