// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IOrangeStrykeLPAutomatorV2_1} from "../v2_1/IOrangeStrykeLPAutomatorV2_1.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IOrangeQuoter} from "./../interfaces/IOrangeQuoter.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "./../lib/UniswapV3SingleTickLiquidityLibV2.sol";
import {IUniswapV3PoolAdapter} from "../pool-adapter/IUniswapV3PoolAdapter.sol";

contract StrykeVaultInspectorV2 {
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using SafeCast for uint256;
    using TickMath for int24;

    /// @dev Cache position calculation data to avoid stack too deep error. Used in "freeAssets".
    struct PositionCalcCache {
        uint128 liquidity;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0;
        uint256 amount1;
        uint256 swapFee0;
        uint256 swapFee1;
        uint160 sqrtRatioX96;
    }

    /**
     * @dev Retrieves the total free liquidity in token0 and token1 in the pool.
     * @param automator The automator contract.
     * @return sumAmount0 The total free liquidity in token0.
     * @return sumAmount1 The total free liquidity in token1.
     */
    function freePoolPositionInToken01(
        IOrangeStrykeLPAutomatorV2_1 automator
    ) public view returns (uint256 sumAmount0, uint256 sumAmount1) {
        IUniswapV3SingleTickLiquidityHandlerV2 _handler = automator.handler();
        // when handler is paused, no liquidity can be withdrawn
        if (_handler.paused()) return (0, 0);

        IUniswapV3PoolAdapter poolAdapter = automator.poolAdapter();
        address _handlerHook = automator.handlerHook();
        int24[] memory _ticks = automator.getActiveTicks();
        int24 _spacing = automator.poolTickSpacing();
        uint256 _tLen = _ticks.length;

        PositionCalcCache memory _cache;

        (uint160 _sqrtRatioX96, , , , , , ) = poolAdapter.slot0();

        for (uint256 i = 0; i < _tLen; ) {
            _cache.lowerTick = _ticks[i];
            _cache.upperTick = _cache.lowerTick + _spacing;

            (, _cache.liquidity, , _cache.swapFee0, _cache.swapFee1) = _handler.positionDetail(
                address(automator),
                _handler.tokenId(poolAdapter.pool(), _handlerHook, _cache.lowerTick, _cache.upperTick)
            );

            (_cache.amount0, _cache.amount1) = LiquidityAmounts.getAmountsForLiquidity(
                _sqrtRatioX96,
                _cache.lowerTick.getSqrtRatioAtTick(),
                _cache.upperTick.getSqrtRatioAtTick(),
                _cache.liquidity
            );

            sumAmount0 += (_cache.amount0 + _cache.swapFee0);
            sumAmount1 += (_cache.amount1 + _cache.swapFee1);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Retrieves the total liquidity of a given tick range.
     * @param tick The tick value representing the range.
     * @return The total liquidity of the tick range.
     */
    function getTickAllLiquidity(IOrangeStrykeLPAutomatorV2_1 automator, int24 tick) external view returns (uint128) {
        IUniswapV3SingleTickLiquidityHandlerV2 _handler = automator.handler();
        address _pool = automator.poolAdapter().pool();
        address _handlerHook = automator.handlerHook();
        int24 _spacing = automator.poolTickSpacing();

        uint256 _share = _handler.balanceOf(
            address(automator),
            _handler.tokenId(_pool, _handlerHook, tick, tick + _spacing)
        );

        if (_share == 0) return 0;

        return
            _handler.convertToAssets(_share.toUint128(), _handler.tokenId(_pool, _handlerHook, tick, tick + _spacing));
    }

    /**
     * @dev Retrieves the amount of free liquidity for a given tick.
     * @param tick The tick value for which to retrieve the free liquidity.
     * @return freeLiquidity The amount of free liquidity for the specified tick.
     */
    function getTickFreeLiquidity(
        IOrangeStrykeLPAutomatorV2_1 automator,
        int24 tick
    ) external view returns (uint128 freeLiquidity) {
        IUniswapV3SingleTickLiquidityHandlerV2 _handler = automator.handler();
        address _pool = automator.poolAdapter().pool();
        address _handlerHook = automator.handlerHook();
        int24 _spacing = automator.poolTickSpacing();

        (, freeLiquidity, , , ) = _handler.positionDetail(
            address(automator),
            _handler.tokenId(_pool, _handlerHook, tick, tick + _spacing)
        );
    }

    /**
     * @dev Calculates the total free assets in Dopex pools and returns the sum.
     * Free assets are the assets that can be redeemed from the pools.
     * This function iterates through the active ticks in the pool and calculates the liquidity
     * that can be redeemed for each tick. It then converts the liquidity to token amounts using
     * the current sqrt ratio and tick values. The sum of token amounts is calculated and merged
     * with the total assets in the automator. Finally, the quote value is obtained using the
     * current tick and the base value, and returned as the result.
     * @return The total free assets in Dopex pools.
     */
    function freeAssets(IOrangeStrykeLPAutomatorV2_1 automator) public view returns (uint256) {
        // 1. calculate the free token0 & token1 in Dopex pools
        (uint256 _sum0, uint256 _sum1) = freePoolPositionInToken01(automator);

        // 2. merge into the total assets in the automator
        IERC20 _asset = automator.asset();
        IERC20 _counterAsset = automator.counterAsset();
        (uint256 _base, uint256 _quote) = (
            _counterAsset.balanceOf(address(automator)),
            _asset.balanceOf(address(automator))
        );

        if (address(_asset) == automator.poolAdapter().token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            automator.quoter().getQuote(
                IOrangeQuoter.QuoteRequest({
                    baseToken: address(_counterAsset),
                    quoteToken: address(_asset),
                    baseAmount: _base,
                    baseUsdFeed: automator.counterAssetUsdFeed(),
                    quoteUsdFeed: automator.assetUsdFeed()
                })
            );
    }

    function convertSharesToPairAssets(
        IOrangeStrykeLPAutomatorV2_1 automator,
        uint256 shares
    ) external view returns (uint256 assets, uint256 counterAssets) {
        (address token0, address token1) = (automator.poolAdapter().token0(), automator.poolAdapter().token1());
        (uint256 position0, uint256 position1) = freePoolPositionInToken01(automator);
        (uint256 balance0, uint256 balance1) = (
            IERC20(token0).balanceOf(address(automator)),
            IERC20(token1).balanceOf(address(automator))
        );

        assets = FullMath.mulDiv(position0 + balance0, shares, IERC20(address(automator)).totalSupply());
        counterAssets = FullMath.mulDiv(position1 + balance1, shares, IERC20(address(automator)).totalSupply());

        if (token1 == address(automator.asset())) (assets, counterAssets) = (counterAssets, assets);
    }

    /**
     * @dev Retrieves the positions of the automator.
     * @return balanceDepositAsset The balance of the deposit asset.
     * @return balanceCounterAsset The balance of the counter asset.
     * @return rebalanceTicks An array of structs representing the active ticks and its liquidity.
     */
    function getAutomatorPositions(
        IOrangeStrykeLPAutomatorV2_1 automator
    )
        external
        view
        returns (
            uint256 balanceDepositAsset,
            uint256 balanceCounterAsset,
            IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory rebalanceTicks
        )
    {
        rebalanceTicks = _rebalanceTicks(automator);

        IERC20 _asset = automator.asset();
        IERC20 _counterAsset = automator.counterAsset();

        return (_asset.balanceOf(address(automator)), _counterAsset.balanceOf(address(automator)), rebalanceTicks);
    }

    function _rebalanceTicks(
        IOrangeStrykeLPAutomatorV2_1 automator
    ) private view returns (IOrangeStrykeLPAutomatorV2_1.RebalanceTick[] memory rebalanceTicks) {
        address _pool = automator.poolAdapter().pool();
        IUniswapV3SingleTickLiquidityHandlerV2 _handler = automator.handler();
        address _handlerHook = automator.handlerHook();
        int24 _spacing = automator.poolTickSpacing();
        int24[] memory _ticks = automator.getActiveTicks();
        uint256 _tLen = _ticks.length;
        uint256 _tid;

        PositionCalcCache memory _cache;
        rebalanceTicks = new IOrangeStrykeLPAutomatorV2_1.RebalanceTick[](_tLen);

        for (uint256 i = 0; i < _tLen; ) {
            _cache.lowerTick = _ticks[i];
            _cache.upperTick = _cache.lowerTick + _spacing;
            _tid = _handler.tokenId(_pool, _handlerHook, _cache.lowerTick, _cache.upperTick);

            _cache.liquidity = _handler.convertToAssets(
                (_handler.balanceOf(address(automator), _tid)).toUint128(),
                _tid
            );

            rebalanceTicks[i] = IOrangeStrykeLPAutomatorV2_1.RebalanceTick({
                tick: _cache.lowerTick,
                liquidity: _cache.liquidity
            });

            unchecked {
                i++;
            }
        }
    }
}
