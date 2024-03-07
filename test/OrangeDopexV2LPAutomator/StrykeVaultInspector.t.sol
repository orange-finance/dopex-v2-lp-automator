// SPDX-License-Identifier: GPL-3.0

/* solhint-disable one-contract-per-file, contract-name-camelcase, func-name-mixedcase */
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase */
import {Fixture} from "./v1/Fixture.t.sol";
import {WETH_USDC_Fixture} from "./v1_1/fixture/WETH_USDC_Fixture.t.sol";
import {StrykeVaultInspector} from "./../../contracts/periphery/StrykeVaultInspector.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV1_1.sol";
import {DopexV2Helper} from "../helper/DopexV2Helper.t.sol";
import {UniswapV3Helper} from "../helper/UniswapV3Helper.t.sol";
import {DealExtension} from "../helper/DealExtension.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract TestInspectorWithV1_1 is WETH_USDC_Fixture, DealExtension {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);

        super.setUp();
        inspector = new StrykeVaultInspector();
    }

    function test_freePoolPositionInToken01_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        (uint256 token0, uint256 token1) = inspector.freePoolPositionInToken01(
            IOrangeStrykeLPAutomatorV1_1(address(automator))
        );

        assertEq(token0, 0);
        assertEq(token1, 0);
    }

    function test_freePoolPositionInToken01_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        (uint256 token0, uint256 token1) = inspector.freePoolPositionInToken01(
            IOrangeStrykeLPAutomatorV1_1(address(automator))
        );

        assertApproxEqRel(30 ether, token0, 0.00001e18); // 0.01%
        assertApproxEqRel(300_000e6, token1, 0.00001e18); // 0.01%
    }

    function test_freeAssets_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint256 expected = 100 ether + _getQuote(address(USDC), address(WETH), 1_000_000e6);

        assertApproxEqRel(expected, inspector.freeAssets(IOrangeStrykeLPAutomatorV1_1(address(automator))), 0.0001e18); // 0.1%
    }

    function test_freeAssets_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        uint256 pooled = 70 ether + _getQuote(address(USDC), address(WETH), 700_000e6);
        uint256 positioned = 30 ether + _getQuote(address(USDC), address(WETH), 300_000e6);

        assertApproxEqRel(
            pooled + positioned,
            inspector.freeAssets(IOrangeStrykeLPAutomatorV1_1(address(automator))),
            0.0001e18
        ); // 0.1%
    }

    function test_getAutomatorPositions_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        (
            uint256 balanceDepositAsset,
            uint256 balanceCounterAsset,
            IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[] memory rebalanceTicks
        ) = inspector.getAutomatorPositions(IOrangeStrykeLPAutomatorV1_1(address(automator)));

        assertEq(balanceDepositAsset, 100 ether);
        assertEq(balanceCounterAsset, 1_000_000e6);
        assertEq(rebalanceTicks.length, 0);
    }

    function test_getAutomatorPositions_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        (
            uint256 balanceDepositAsset,
            uint256 balanceCounterAsset,
            IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[] memory rebalanceTicks
        ) = inspector.getAutomatorPositions(IOrangeStrykeLPAutomatorV1_1(address(automator)));

        assertApproxEqRel(70 ether, balanceDepositAsset, 0.00001e18); // 0.01%
        assertApproxEqRel(700_000e6, balanceCounterAsset, 0.00001e18); // 0.01%
        assertEq(rebalanceTicks.length, 6);

        int24[] memory _expectedTicks = new int24[](6);
        _expectedTicks[0] = currentLower - 10;
        _expectedTicks[1] = currentLower - 20;
        _expectedTicks[2] = currentLower - 30;
        _expectedTicks[3] = currentLower + 10;
        _expectedTicks[4] = currentLower + 20;
        _expectedTicks[5] = currentLower + 30;

        for (uint256 i = 0; i < rebalanceTicks.length; i++) {
            int24 tick = rebalanceTicks[i].tick;
            assertEq(tick, _expectedTicks[i]);

            if (tick < currentLower) {
                assertApproxEqRel(
                    pool.singleLiqLeft(tick, 100_000e6),
                    rebalanceTicks[i].liquidity,
                    0.00001e18 // 0.01%
                );
            } else {
                assertApproxEqRel(
                    pool.singleLiqRight(tick, 10 ether),
                    rebalanceTicks[i].liquidity,
                    0.00001e18 // 0.01%
                );
            }
        }
    }

    function test_getTickAllLiquidity_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint128 liquidity = inspector.getTickAllLiquidity(
            IOrangeStrykeLPAutomatorV1_1(address(automator)),
            pool.currentLower()
        );

        assertEq(0, liquidity);
    }

    function test_getTickAllLiquidity_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        for (int24 i = currentLower - 30; i <= currentLower + 30; i += 10) {
            uint128 liquidity = inspector.getTickAllLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), i);

            if (i < currentLower) {
                assertApproxEqRel(pool.singleLiqLeft(i, 100_000e6), liquidity, 0.00001e18); // 0.01%
            } else if (i == currentLower) {
                assertEq(0, liquidity);
            } else {
                assertApproxEqRel(pool.singleLiqRight(i, 10 ether), liquidity, 0.00001e18); // 0.01%
            }
        }
    }

    function test_getTickFreeLiquidity_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint128 liquidity = inspector.getTickFreeLiquidity(
            IOrangeStrykeLPAutomatorV1_1(address(automator)),
            pool.currentLower()
        );

        assertEq(0, liquidity);
    }

    function test_getTickFreeLiquidity_hasPositions_notUtilized() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        for (int24 i = currentLower - 30; i <= currentLower + 30; i += 10) {
            uint128 liquidity = inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), i);

            if (i < currentLower) {
                assertApproxEqRel(pool.singleLiqLeft(i, 100_000e6), liquidity, 0.00001e18); // 0.01%
            } else if (i == currentLower) {
                assertEq(0, liquidity);
            } else {
                assertApproxEqRel(pool.singleLiqRight(i, 10 ether), liquidity, 0.00001e18); // 0.01%
            }
        }
    }

    function test_getTickFreeLiquidity_hasPositions_utilized() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));

        pool.useDopexPosition(address(0), currentLower - 10, pool.freeLiquidityOfTick(address(0), currentLower - 10));
        pool.useDopexPosition(
            address(0),
            currentLower + 10,
            pool.freeLiquidityOfTick(address(0), currentLower + 10) - 1
        );

        assertEq(
            0,
            inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), currentLower - 10)
        );

        assertEq(
            1,
            inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), currentLower + 10)
        );
    }

    function _rebalanceMintSingle(int24 lowerTick, uint128 liquidity) internal {
        IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function _getQuote(address base, address quote, uint128 baseAmount) internal view returns (uint256) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(_currentTick, baseAmount, base, quote);
    }
}

contract TestInspectorWithV1 is Fixture, DealExtension {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    StrykeVaultInspector public inspector;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);

        super.setUp();
        inspector = new StrykeVaultInspector();
    }

    function test_freePoolPositionInToken01_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        (uint256 token0, uint256 token1) = inspector.freePoolPositionInToken01(
            IOrangeStrykeLPAutomatorV1_1(address(automator))
        );

        assertEq(token0, 0);
        assertEq(token1, 0);
    }

    function test_freePoolPositionInToken01_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        (uint256 token0, uint256 token1) = inspector.freePoolPositionInToken01(
            IOrangeStrykeLPAutomatorV1_1(address(automator))
        );

        assertApproxEqRel(30 ether, token0, 0.00001e18); // 0.01%
        assertApproxEqRel(300_000e6, token1, 0.00001e18); // 0.01%
    }

    function test_freeAssets_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint256 expected = 100 ether + _getQuote(address(USDC), address(WETH), 1_000_000e6);

        assertApproxEqRel(expected, inspector.freeAssets(IOrangeStrykeLPAutomatorV1_1(address(automator))), 0.0001e18); // 0.1%
    }

    function test_freeAssets_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        uint256 pooled = 70 ether + _getQuote(address(USDC), address(WETH), 700_000e6);
        uint256 positioned = 30 ether + _getQuote(address(USDC), address(WETH), 300_000e6);

        assertApproxEqRel(
            pooled + positioned,
            inspector.freeAssets(IOrangeStrykeLPAutomatorV1_1(address(automator))),
            0.0001e18
        ); // 0.1%
    }

    function test_getAutomatorPositions_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        (
            uint256 balanceDepositAsset,
            uint256 balanceCounterAsset,
            IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[] memory rebalanceTicks
        ) = inspector.getAutomatorPositions(IOrangeStrykeLPAutomatorV1_1(address(automator)));

        assertEq(balanceDepositAsset, 100 ether);
        assertEq(balanceCounterAsset, 1_000_000e6);
        assertEq(rebalanceTicks.length, 0);
    }

    function test_getAutomatorPositions_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        (
            uint256 balanceDepositAsset,
            uint256 balanceCounterAsset,
            IOrangeStrykeLPAutomatorV1_1.RebalanceTickInfo[] memory rebalanceTicks
        ) = inspector.getAutomatorPositions(IOrangeStrykeLPAutomatorV1_1(address(automator)));

        assertApproxEqRel(70 ether, balanceDepositAsset, 0.00001e18); // 0.01%
        assertApproxEqRel(700_000e6, balanceCounterAsset, 0.00001e18); // 0.01%
        assertEq(rebalanceTicks.length, 6);

        int24[] memory _expectedTicks = new int24[](6);
        _expectedTicks[0] = currentLower - 10;
        _expectedTicks[1] = currentLower - 20;
        _expectedTicks[2] = currentLower - 30;
        _expectedTicks[3] = currentLower + 10;
        _expectedTicks[4] = currentLower + 20;
        _expectedTicks[5] = currentLower + 30;

        for (uint256 i = 0; i < rebalanceTicks.length; i++) {
            int24 tick = rebalanceTicks[i].tick;
            assertEq(tick, _expectedTicks[i]);

            if (tick < currentLower) {
                assertApproxEqRel(
                    pool.singleLiqLeft(tick, 100_000e6),
                    rebalanceTicks[i].liquidity,
                    0.00001e18 // 0.01%
                );
            } else {
                assertApproxEqRel(
                    pool.singleLiqRight(tick, 10 ether),
                    rebalanceTicks[i].liquidity,
                    0.00001e18 // 0.01%
                );
            }
        }
    }

    function test_getTickAllLiquidity_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint128 liquidity = inspector.getTickAllLiquidity(
            IOrangeStrykeLPAutomatorV1_1(address(automator)),
            pool.currentLower()
        );

        assertEq(0, liquidity);
    }

    function test_getTickAllLiquidity_hasPositions() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        for (int24 i = currentLower - 30; i <= currentLower + 30; i += 10) {
            uint128 liquidity = inspector.getTickAllLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), i);

            if (i < currentLower) {
                assertApproxEqRel(pool.singleLiqLeft(i, 100_000e6), liquidity, 0.00001e18); // 0.01%
            } else if (i == currentLower) {
                assertEq(0, liquidity);
            } else {
                assertApproxEqRel(pool.singleLiqRight(i, 10 ether), liquidity, 0.00001e18); // 0.01%
            }
        }
    }

    function test_getTickFreeLiquidity_noPositions() public {
        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        uint128 liquidity = inspector.getTickFreeLiquidity(
            IOrangeStrykeLPAutomatorV1_1(address(automator)),
            pool.currentLower()
        );

        assertEq(0, liquidity);
    }

    function test_getTickFreeLiquidity_hasPositions_notUtilized() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        for (int24 i = currentLower - 30; i <= currentLower + 30; i += 10) {
            uint128 liquidity = inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), i);

            if (i < currentLower) {
                assertApproxEqRel(pool.singleLiqLeft(i, 100_000e6), liquidity, 0.00001e18); // 0.01%
            } else if (i == currentLower) {
                assertEq(0, liquidity);
            } else {
                assertApproxEqRel(pool.singleLiqRight(i, 10 ether), liquidity, 0.00001e18); // 0.01%
            }
        }
    }

    function test_getTickFreeLiquidity_hasPositions_utilized() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));

        pool.useDopexPosition(address(0), currentLower - 10, pool.freeLiquidityOfTick(address(0), currentLower - 10));
        pool.useDopexPosition(
            address(0),
            currentLower + 10,
            pool.freeLiquidityOfTick(address(0), currentLower + 10) - 1
        );

        assertEq(
            0,
            inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), currentLower - 10)
        );

        assertEq(
            1,
            inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), currentLower + 10)
        );
    }
}
