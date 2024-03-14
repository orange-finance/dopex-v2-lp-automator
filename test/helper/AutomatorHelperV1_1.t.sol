// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase, const-name-snakecase, custom-errors */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts//proxy/ERC1967/ERC1967Proxy.sol";

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

import {OrangeStrykeLPAutomatorV1_1} from "./../../contracts/OrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorState} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorState.sol";

import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";

import {Vm} from "forge-std/Test.sol";

library auto11 {
    Vm public constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    /*/////////////////////////////////////////////////////////////////////
                                OrangeStrykeLPAutomatorV1_1 utilities
    /////////////////////////////////////////////////////////////////////*/

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

    function deploy(DeployArgs memory args) external returns (OrangeStrykeLPAutomatorV1_1 automator) {
        address impl = address(new OrangeStrykeLPAutomatorV1_1());
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

        automator = OrangeStrykeLPAutomatorV1_1(proxy);

        vm.startPrank(args.admin);
        automator.setDepositCap(args.depositCap);
        automator.setStrategist(args.strategist, true);
        automator.quoter().setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        automator.quoter().setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);
        vm.stopPrank();

        vm.prank(args.dopexV2ManagerOwner);
        args.manager.updateWhitelistHandlerWithApp(address(args.handler), address(args.admin), true);
    }

    function rebalanceMintSingle(IOrangeStrykeLPAutomatorV1_1 automator, int24 lowerTick, uint128 liquidity) internal {
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMint(
        IOrangeStrykeLPAutomatorV1_1 automator,
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory ticksMint
    ) internal {
        automator.rebalance(
            ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMintWithSwap(
        IOrangeStrykeLPAutomatorV1_1 automator,
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory ticksMint,
        IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams memory swapParams
    ) internal {
        automator.rebalance(ticksMint, new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0), swapParams);
    }

    function calculateRebalanceSwapParamsInRebalance(
        IOrangeStrykeLPAutomatorV1_1 automator,
        IUniswapV3Pool pool,
        IERC20 asset,
        IERC20 counterAsset,
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory ticksMint,
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory ticksBurn
    ) public view returns (IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams memory) {
        uint256 _mintAssets;
        uint256 _mintCAssets;
        uint256 _burnAssets;
        uint256 _burnCAssets;

        if (pool.token0() == address(asset)) {
            (_mintAssets, _mintCAssets) = estimateTotalTokensFromPositions(pool, ticksMint);
            (_burnAssets, _burnCAssets) = estimateTotalTokensFromPositions(pool, ticksBurn);
        } else {
            (_mintCAssets, _mintAssets) = estimateTotalTokensFromPositions(pool, ticksMint);
            (_burnCAssets, _burnAssets) = estimateTotalTokensFromPositions(pool, ticksBurn);
        }

        uint256 _freeAssets = _burnAssets + asset.balanceOf(address(automator));
        uint256 _freeCAssets = _burnCAssets + counterAsset.balanceOf(address(automator));

        uint256 _assetsShortage;
        if (_mintAssets > _freeAssets) _assetsShortage = _mintAssets - _freeAssets;

        uint256 _counterAssetsShortage;
        if (_mintCAssets > _freeCAssets) _counterAssetsShortage = _mintCAssets - _freeCAssets;

        if (_assetsShortage > 0 && _counterAssetsShortage > 0) revert("InvalidPositionConstruction");

        uint256 _maxCounterAssetsUseForSwap;
        if (_assetsShortage > 0) {
            _maxCounterAssetsUseForSwap = _freeCAssets - _mintCAssets;
        }

        uint256 _maxAssetsUseForSwap;
        if (_counterAssetsShortage > 0) {
            _maxAssetsUseForSwap = _freeAssets - _mintAssets;
        }

        if (_assetsShortage != 0 && _counterAssetsShortage != 0) revert("LiquidityTooLarge");

        return
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams({
                assetsShortage: _assetsShortage,
                counterAssetsShortage: _counterAssetsShortage,
                maxCounterAssetsUseForSwap: _maxCounterAssetsUseForSwap,
                maxAssetsUseForSwap: _maxAssetsUseForSwap
            });
    }

    function estimateTotalTokensFromPositions(
        IUniswapV3Pool pool,
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory positions
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
