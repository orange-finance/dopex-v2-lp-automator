// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "./../../../contracts/interfaces/IOrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorState} from "./../../../contracts/interfaces/IOrangeStrykeLPAutomatorState.sol";
import {ChainlinkQuoter} from "./../../../contracts/ChainlinkQuoter.sol";
import {deployAutomatorHarness, DeployArgs, AutomatorHarness} from "../../OrangeDopexV2LPAutomator/v1_1/harness/AutomatorHarness.t.sol";
import {DealExtension} from "../../helper/DealExtension.t.sol";
import {auto11} from "../../helper/AutomatorHelperV1_1.t.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

/* solhint-disable func-name-mixedcase, contract-name-camelcase */
contract TestOrangeStrykeLPAutomatorV1_1Rebalance is WETH_USDC_Fixture, DealExtension {
    using FixedPointMathLib for uint256;
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);
        super.setUp();

        vm.startPrank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
        manager.updateWhitelistHandlerWithApp(alice, address(this), true);
        vm.stopPrank();
    }

    function test_rebalance_fromInitialState() public {
        // current tick: -196791
        dealUsdc(address(automator), 10000e6);

        // mint positions using 95% of the balance of USDC (9500 USDC)
        // half of USDC should be swapped to WETH
        // liquidity(-196820, -196780, 4250USDC, 1.4WETH) = 55005494315662841
        _rebalanceMintPositions(55005494315662841, -196820, -196810, -196780, -196770);

        // check if the automator's total assets are correct
        // quote for 10000 USDC = 3.5 WETH
        assertApproxEqRel(automator.totalAssets(), 3516391657860170805, 0.0005e18); // max 0.05% diff (swap fee)

        // check if the automator has the correct liquidity
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196820), 55005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196810), 55005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196780), 55005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196770), 55005494315662841, 0.001e18);

        // burn some positions and mint new ones
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2); // prettier-ignore
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory _ticksBurn = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2); // prettier-ignore
        _ticksBurn[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196820, liquidity: 50000000000000000});
        _ticksBurn[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196810, liquidity: 50000000000000000});
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196760, liquidity: 50000000000000000});
        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196750, liquidity: 50000000000000000});

        automator.rebalance(_ticksMint, _ticksBurn, auto11.calculateRebalanceSwapParamsInRebalance(automator, pool, WETH, USDC, _ticksMint, _ticksBurn)); // prettier-ignore

        // check if the automator's total assets are correct
        assertApproxEqRel(automator.totalAssets(), 3516391657860170805, 0.0005e18); // max 0.05% diff (swap fee)

        // check if the automator has the correct liquidity
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196820), 5005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196810), 5005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196780), 55005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196770), 55005494315662841, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196760), 50000000000000000, 0.001e18);
        assertApproxEqRel(pool.dopexLiquidityOf(address(0), address(automator), -196750), 50000000000000000, 0.001e18);
    }

    function test_rebalance_activeTickRemoved() public {
        // current tick: -196791
        deal(address(WETH), address(automator), 10 ether);
        deal(address(WETH), alice, 10 ether);

        // liquidity(10 WETH, -196760, -196750) = 1068525215797178784
        _rebalanceMintSingle(-196760, 1068525215797178784);

        // additional liquidity is required; otherwise, the liquidity position of the automator will remain at 1 in the pool.
        vm.startPrank(alice);
        WETH.approve(address(manager), type(uint256).max);
        _mintDopexPosition(-196760, -196750, 1068525215797178784);
        vm.stopPrank();

        int24[] memory _ticks = automator.getActiveTicks();
        assertEq(_ticks.length, 1);

        _rebalanceBurnSingle(-196760, 1068525215797178785);

        _ticks = automator.getActiveTicks();

        assertEq(_ticks.length, 0);
    }

    function test_rebalance_currentTickShouldBeSkipped() public {
        // current tick: -196791
        deal(address(WETH), address(automator), 10 ether);
        dealUsdc(address(automator), 10_000e6);

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](3);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196810, liquidity: 1e10});
        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196800, liquidity: 1e10});
        _ticksMint[2] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: -196790, liquidity: 1e10});

        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );

        int24[] memory _ticks = automator.getActiveTicks();
        assertEq(_ticks.length, 2);
        assertEq(_ticks[0], -196810);
        assertEq(_ticks[1], -196790);
    }

    function test_rebalance_activeTicksFull() public {
        AutomatorHarness _automator = deployAutomatorHarness(
            DeployArgs({
                name: "IOrangeStrykeLPAutomatorV1_1",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                dopexV2ManagerOwner: managerOwner,
                strategist: address(this),
                depositCap: 10000e6
            })
        );

        deal(address(WETH), address(_automator), 10 ether);

        for (int24 i = 1; i < 151; i++) {
            _automator.pushActiveTick(i);
        }

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: 1000, liquidity: 1e6});

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.MaxTicksReached.selector);
        _automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function _rebalanceMintPositions(uint128 liquidityPerTick, int24 t1, int24 t2, int24 t3, int24 t4) internal {
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](4); // prettier-ignore
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory _ticksBurn = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0); // prettier-ignore
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: t1, liquidity: liquidityPerTick});
        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: t2, liquidity: liquidityPerTick});
        _ticksMint[2] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: t3, liquidity: liquidityPerTick});
        _ticksMint[3] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: t4, liquidity: liquidityPerTick});

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            auto11.calculateRebalanceSwapParamsInRebalance(automator, pool, WETH, USDC, _ticksMint, _ticksBurn)
        );
    }

    function _rebalanceMintSingle(int24 lowerTick, uint128 liquidity) internal {
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function _rebalanceBurnSingle(int24 lowerTick, uint128 liquidity) internal {
        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksBurn = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](1);
        _ticksBurn[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            _ticksBurn,
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function _mintDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidity) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams
            memory _params = IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: lowerTick,
                tickUpper: upperTick,
                liquidity: liquidity
            });

        manager.mintPosition(handlerV2, abi.encode(_params));
    }
}
