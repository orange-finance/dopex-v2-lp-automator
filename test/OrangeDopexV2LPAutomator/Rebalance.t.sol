// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.t.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {OrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";
import {AutomatorUniswapV3PoolLib} from "../../contracts/lib/AutomatorUniswapV3PoolLib.sol";
import {IOrangeDopexV2LPAutomator} from "../../contracts/interfaces/IOrangeDopexV2LPAutomator.sol";
import {deployAutomatorHarness, AutomatorHarness} from "../OrangeDopexV2LPAutomator/harness/AutomatorHarness.t.sol";
import "../helper/AutomatorHelper.t.sol";

contract TestOrangeDopexV2LPAutomatorRebalance is Fixture {
    using AutomatorUniswapV3PoolLib for IUniswapV3Pool;
    using FixedPointMathLib for uint256;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    // ? currently test getting stacked in this case
    // function test_rebalance_fromInitialState() public {
    //     deal(address(USDCE), address(automator), 10000e6);

    //     uint256 _balanceBasedUsdce = USDCE.balanceOf(address(automator));
    //     uint256 _balanceBasedWeth = _getQuote(address(USDCE), address(WETH), uint128(_balanceBasedUsdce));

    //     (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
    //     (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

    //     /*///////////////////////////////////////////////////////////////////////////////////
    //                                 case: mint positions
    //     ///////////////////////////////////////////////////////////////////////////////////*/

    //     _mint(_balanceBasedUsdce, _balanceBasedWeth, _oor_belowLower, _oor_aboveLower);

    //     assertApproxEqRel(automator.totalAssets(), _balanceBasedWeth, 0.0005e18); // max 0.05% diff (swap fee)

    //     /*///////////////////////////////////////////////////////////////////////////////////
    //                                 case: burn & mint positions
    //     ///////////////////////////////////////////////////////////////////////////////////*/

    //     _burnAndMint(_balanceBasedUsdce, _oor_belowLower, _oor_aboveLower);

    //     assertApproxEqRel(automator.totalAssets(), _balanceBasedWeth, 0.0005e18); // max 0.05% diff (swap fee)
    // }

    function test_rebalance_activeTickRemoved() public {
        deal(address(WETH), address(automator), 10 ether);

        // 5 WETH = 11009961214 USDC.e (currentTick: -199349)
        // liquidity(-199330, -199320) = 469840801795273610 (currentTick: -199349)

        _rebalanceMintSingle(-199330, 469840801795273610);

        int24[] memory _ticks = automator.getActiveTicks();
        assertEq(_ticks.length, 1);

        _rebalanceBurnSingle(-199330, 469840801795273609);

        _ticks = automator.getActiveTicks();
        assertEq(_ticks.length, 0);
    }

    function test_rebalance_currentTickShouldBeSkipped() public {
        deal(address(WETH), address(automator), 10 ether);
        deal(address(USDCE), address(automator), 10_000e6);

        // 5 WETH = 11009961214 USDC.e (currentTick: -199349)
        // liquidity(-199330, -199320) = 469840801795273610 (currentTick: -199349)

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new OrangeDopexV2LPAutomator.RebalanceTickInfo[](3);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: -199360, liquidity: 1e10});
        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: -199350, liquidity: 1e10});
        _ticksMint[2] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: -199340, liquidity: 1e10});

        automator.rebalance(
            _ticksMint,
            new OrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        int24[] memory _ticks = automator.getActiveTicks();
        assertEq(_ticks.length, 2);
        assertEq(_ticks[0], -199360);
        assertEq(_ticks[1], -199340);
    }

    function test_rebalance_activeTicksFull() public {
        AutomatorHarness _automator = deployAutomatorHarness(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: uniV3Handler,
                router: router,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D))
            }),
            address(this),
            10_000e6
        );

        deal(address(WETH), address(_automator), 10 ether);

        for (int24 i = 1; i < 121; i++) {
            _automator.pushActiveTick(i);
        }

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new OrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: 1000, liquidity: 1e6});

        vm.expectRevert(OrangeDopexV2LPAutomator.MaxTicksReached.selector);
        _automator.rebalance(
            _ticksMint,
            new OrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function test_onERC1155BatchReceived() public {
        assertEq(
            automator.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), ""),
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
        );
    }

    function _mint(uint256 _amountUsdce, uint256 _amountWeth, int24 _oor_belowLower, int24 _oor_aboveLower) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);

        // token0: WETH, token1: USDCE
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                0,
                (_amountUsdce / 2) - (_amountUsdce / 2).mulDivDown(pool.fee(), 1e6 - pool.fee())
            )
        });

        (uint256 _a0, uint256 _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_belowLower),
            TickMath.getSqrtRatioAtTick(_oor_belowLower + pool.tickSpacing()),
            _ticksMint[0].liquidity
        );

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                (_amountWeth / 2) - (_amountWeth / 2).mulDivDown(pool.fee(), 1e6 - pool.fee()),
                0
            )
        });

        (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower + pool.tickSpacing()),
            _ticksMint[1].liquidity
        );

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksBurn = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0);

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            AutomatorHelper.calculateRebalanceSwapParamsInRebalance(
                automator,
                pool,
                USDCE,
                WETH,
                _ticksMint,
                _ticksBurn
            )
        );
    }

    function _burnAndMint(uint256 _amountUsdce, int24 _oor_belowLower, int24 _oor_aboveLower) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                0,
                (_amountUsdce / 3) - (_amountUsdce / 3).mulDivDown(pool.fee(), 1e6 - pool.fee())
            )
        });

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksBurn = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksBurn[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: automator.getTickFreeLiquidity(_oor_belowLower)
        });

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            AutomatorHelper.calculateRebalanceSwapParamsInRebalance(
                automator,
                pool,
                USDCE,
                WETH,
                _ticksMint,
                _ticksBurn
            )
        );
    }
}
