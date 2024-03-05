// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

import {OrangeDopexV2LPAutomatorV1, IOrangeDopexV2LPAutomatorV1} from "../../contracts/OrangeDopexV2LPAutomatorV1.sol";

import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";

import {Vm} from "forge-std/Test.sol";

library AutomatorHelper {
    ISwapRouter public constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /*/////////////////////////////////////////////////////////////////////
                                OrangeDopexV2LPAutomatorV1 utilities
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

    function deployOrangeDopexV2LPAutomatorV1(
        Vm vm,
        DeployArgs memory args
    ) external returns (OrangeDopexV2LPAutomatorV1 automator) {
        automator = new OrangeDopexV2LPAutomatorV1(
            OrangeDopexV2LPAutomatorV1.InitArgs({
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

        vm.startPrank(args.admin);
        automator.setDepositCap(args.depositCap);
        automator.grantRole(automator.STRATEGIST_ROLE(), args.strategist);
        automator.quoter().setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        automator.quoter().setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);
        vm.stopPrank();

        vm.prank(args.dopexV2ManagerOwner);
        args.manager.updateWhitelistHandlerWithApp(address(args.handler), address(args.admin), true);
    }

    function rebalanceMintSingle(IOrangeDopexV2LPAutomatorV1 automator, int24 lowerTick, uint128 liquidity) internal {
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomatorV1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMint(
        IOrangeDopexV2LPAutomatorV1 automator,
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[] memory ticksMint
    ) internal {
        automator.rebalance(
            ticksMint,
            new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomatorV1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMintWithSwap(
        IOrangeDopexV2LPAutomatorV1 automator,
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomatorV1.RebalanceSwapParams memory swapParams
    ) internal {
        automator.rebalance(ticksMint, new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](0), swapParams);
    }

    function calculateRebalanceSwapParamsInRebalance(
        IOrangeDopexV2LPAutomatorV1 automator,
        IUniswapV3Pool pool,
        IERC20 asset,
        IERC20 counterAsset,
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[] memory ticksBurn
    ) public view returns (IOrangeDopexV2LPAutomatorV1.RebalanceSwapParams memory) {
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
            IOrangeDopexV2LPAutomatorV1.RebalanceSwapParams({
                assetsShortage: _assetsShortage,
                counterAssetsShortage: _counterAssetsShortage,
                maxCounterAssetsUseForSwap: _maxCounterAssetsUseForSwap,
                maxAssetsUseForSwap: _maxAssetsUseForSwap
            });
    }

    function estimateTotalTokensFromPositions(
        IUniswapV3Pool pool,
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[] memory positions
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
