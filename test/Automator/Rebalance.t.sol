// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.sol";
import {UniswapV3PoolLib} from "../../contracts/lib/UniswapV3PoolLib.sol";

contract TestAutomatorRebalance is Fixture {
    using UniswapV3PoolLib for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    // function test_calculateRebalanceSwapParamsInRebalance() public {
    // UniswapV3PoolLib.Position[] memory _mintPositions = new UniswapV3PoolLib.Position[](1);
    // _mintPositions[0].tickLower = -199310;
    // Automator.RebalanceSwapParams _swapAmounts = automator.calculateRebalanceSwapParamsInRebalance(_mintPositions, _burnPositions);
    // }

    function test_rebalance_fromInitialState() public {
        deal(address(USDCE), address(automator), 10000e6);

        uint256 _balanceBasedUsdce = USDCE.balanceOf(address(automator));
        uint256 _balanceBasedWeth = _getQuote(address(USDCE), address(WETH), uint128(_balanceBasedUsdce));

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        Automator.RebalanceMintParams[] memory _mintParams = new Automator.RebalanceMintParams[](2);

        // token0: WETH, token1: USDCE
        _mintParams[0] = Automator.RebalanceMintParams({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, 0, _balanceBasedUsdce / 2)
        });

        (uint256 _a0, uint256 _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_belowLower),
            TickMath.getSqrtRatioAtTick(_oor_belowLower + pool.tickSpacing()),
            _mintParams[0].liquidity
        );

        emit log_named_uint("a0 below", _a0);
        emit log_named_uint("a1 below", _a1);

        _mintParams[1] = Automator.RebalanceMintParams({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _balanceBasedWeth / 2, 0)
        });

        (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower + pool.tickSpacing()),
            _mintParams[1].liquidity
        );

        emit log_named_uint("a0 above", _a0);
        emit log_named_uint("a1 above", _a1);
        emit log_named_uint("a0 above in usdce", _getQuote(address(WETH), address(USDCE), uint128(_a0)));

        Automator.RebalanceBurnParams[] memory _burnParams = new Automator.RebalanceBurnParams[](0);

        UniswapV3PoolLib.Position[] memory _mintPositions = new UniswapV3PoolLib.Position[](2);
        _mintPositions[0] = UniswapV3PoolLib.Position({
            tickLower: _mintParams[0].tick,
            tickUpper: _mintParams[0].tick + pool.tickSpacing(),
            liquidity: _mintParams[0].liquidity
        });

        _mintPositions[1] = UniswapV3PoolLib.Position({
            tickLower: _mintParams[1].tick,
            tickUpper: _mintParams[1].tick + pool.tickSpacing(),
            liquidity: _mintParams[1].liquidity
        });

        automator.inefficientRebalance(
            _mintParams,
            _burnParams,
            automator.calculateRebalanceSwapParamsInRebalance(_mintPositions, new UniswapV3PoolLib.Position[](0))
        );
    }
}
