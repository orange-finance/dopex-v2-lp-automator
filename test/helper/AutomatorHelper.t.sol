// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";

import {OrangeDopexV2LPAutomator, IOrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";

import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";

import {AutomatorUniswapV3PoolLib} from "../../contracts/lib/AutomatorUniswapV3PoolLib.sol";

import {Vm} from "forge-std/Test.sol";

library AutomatorHelper {
    using AutomatorUniswapV3PoolLib for IUniswapV3Pool;
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /*/////////////////////////////////////////////////////////////////////
                                OrangeDopexV2LPAutomator utilities
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
        IUniswapV3SingleTickLiquidityHandler handler;
        IUniswapV3Pool pool;
        IERC20 asset;
        uint256 minDepositAssets;
        uint256 depositCap;
    }

    function deployOrangeDopexV2LPAutomator(
        Vm vm,
        DeployArgs memory args
    ) external returns (OrangeDopexV2LPAutomator automator) {
        automator = new OrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomator.InitArgs({
                name: args.name,
                symbol: args.symbol,
                admin: args.admin,
                manager: args.manager,
                handler: args.handler,
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

    function rebalanceMintSingle(IOrangeDopexV2LPAutomator automator, int24 lowerTick, uint128 liquidity) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMint(
        IOrangeDopexV2LPAutomator automator,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint
    ) internal {
        automator.rebalance(
            ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMintWithSwap(
        IOrangeDopexV2LPAutomator automator,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomator.RebalanceSwapParams memory swapParams
    ) internal {
        automator.rebalance(ticksMint, new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0), swapParams);
    }

    function calculateRebalanceSwapParamsInRebalance(
        IOrangeDopexV2LPAutomator automator,
        IUniswapV3Pool pool,
        IERC20 asset,
        IERC20 counterAsset,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksBurn
    ) public view returns (IOrangeDopexV2LPAutomator.RebalanceSwapParams memory) {
        uint256 _mintAssets;
        uint256 _mintCAssets;
        uint256 _burnAssets;
        uint256 _burnCAssets;

        if (pool.token0() == address(asset)) {
            (_mintAssets, _mintCAssets) = pool.estimateTotalTokensFromPositions(ticksMint);
            (_burnAssets, _burnCAssets) = pool.estimateTotalTokensFromPositions(ticksBurn);
        } else {
            (_mintCAssets, _mintAssets) = pool.estimateTotalTokensFromPositions(ticksMint);
            (_burnCAssets, _burnAssets) = pool.estimateTotalTokensFromPositions(ticksBurn);
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
            IOrangeDopexV2LPAutomator.RebalanceSwapParams({
                assetsShortage: _assetsShortage,
                counterAssetsShortage: _counterAssetsShortage,
                maxCounterAssetsUseForSwap: _maxCounterAssetsUseForSwap,
                maxAssetsUseForSwap: _maxAssetsUseForSwap
            });
    }
}
