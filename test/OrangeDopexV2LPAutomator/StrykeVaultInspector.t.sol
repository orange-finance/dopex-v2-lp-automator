// SPDX-License-Identifier: GPL-3.0

/* solhint-disable one-contract-per-file, contract-name-camelcase, func-name-mixedcase */
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase */
import {WETH_USDC_Fixture} from "./v1_1/fixture/WETH_USDC_Fixture.t.sol";
import {StrykeVaultInspector} from "./../../contracts/periphery/StrykeVaultInspector.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorState} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorState.sol";
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
            IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory rebalanceTicks
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
            IOrangeStrykeLPAutomatorState.RebalanceTickInfo[] memory rebalanceTicks
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

    function test_getTickFreeLiquidity_hasPositions_allLiquidityShouldBeFree() public {
        int24 currentLower = UniswapV3Helper.currentLower(pool);

        deal(address(WETH), address(automator), 100 ether);
        dealUsdc(address(automator), 1_000_000e6);
        deal(address(WETH), alice, 100 ether);
        dealUsdc(alice, 1_000_000e6);
        vm.startPrank(alice);
        WETH.approve(address(manager), 100 ether);
        USDC.approve(address(manager), 1_000_000e6);
        vm.stopPrank();

        _rebalanceMintSingle(currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6));
        _rebalanceMintSingle(currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6));
        _rebalanceMintSingle(currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6));

        _rebalanceMintSingle(currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether));
        _rebalanceMintSingle(currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether));
        _rebalanceMintSingle(currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether));

        // mint position by alice to free up all automator's liquidity
        pool.mintDopexPosition(address(0), currentLower - 10, pool.singleLiqLeft(currentLower - 10, 100_000e6), alice);
        pool.mintDopexPosition(address(0), currentLower - 20, pool.singleLiqLeft(currentLower - 20, 100_000e6), alice);
        pool.mintDopexPosition(address(0), currentLower - 30, pool.singleLiqLeft(currentLower - 30, 100_000e6), alice);

        pool.mintDopexPosition(address(0), currentLower + 10, pool.singleLiqRight(currentLower + 10, 10 ether), alice);
        pool.mintDopexPosition(address(0), currentLower + 20, pool.singleLiqRight(currentLower + 20, 10 ether), alice);
        pool.mintDopexPosition(address(0), currentLower + 30, pool.singleLiqRight(currentLower + 30, 10 ether), alice);

        for (int24 i = currentLower - 30; i <= currentLower + 30; i += 10) {
            uint128 liquidity = inspector.getTickFreeLiquidity(IOrangeStrykeLPAutomatorV1_1(address(automator)), i);

            if (i == currentLower) {
                assertEq(0, liquidity);
                continue;
            }

            uint256 tid = pool.tokenId(address(0), i);
            uint256 shares = handlerV2.balanceOf(address(automator), tid);

            assertEq(liquidity, handlerV2.convertToAssets(uint128(shares), tid), "all liquidity should be free");
            assertEq(
                shares,
                handlerV2.convertToShares(uint128(liquidity), tid),
                "all free liquidity should be converted to shares"
            );

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
            pool.freeLiquidityOfTick(address(0), currentLower + 10) - 2
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

    function test_convertSharesToPairAssets() public {
        automator.setDepositCap(200 ether);
        // alice deposit 100 WETH
        _depositFrom(alice, 100 ether);
        // bob deposit 100 WETH
        _depositFrom(bob, 100 ether);

        // assume vault takes 1M USDC profit
        dealUsdc(address(automator), 1_000_000e6);

        int24 lt = pool.currentLower();

        // liquidize assets
        _rebalanceMintSingle(lt - 40, pool.singleLiqLeft(lt - 30, 100_000e6)); // liquidize 100k USDC
        _rebalanceMintSingle(lt - 30, pool.singleLiqLeft(lt - 20, 100_000e6)); // liquidize 100k USDC
        _rebalanceMintSingle(lt - 20, pool.singleLiqLeft(lt - 10, 100_000e6)); // liquidize 100k USDC
        _rebalanceMintSingle(lt + 10, pool.singleLiqRight(lt + 10, 10 ether)); // liquidize 10 WETH
        _rebalanceMintSingle(lt + 20, pool.singleLiqRight(lt + 20, 10 ether)); // liquidize 10 WETH
        _rebalanceMintSingle(lt + 30, pool.singleLiqRight(lt + 30, 10 ether)); // liquidize 10 WETH

        pool.useDopexPosition(address(0), lt - 20, pool.freeLiquidityOfTick(address(0), lt - 20)); // utilize 100k USDC
        pool.useDopexPosition(address(0), lt + 10, pool.freeLiquidityOfTick(address(0), lt + 10)); // utilize 10 WETH

        // convert shares to pair assets
        (uint256 weth, uint256 usdc) = inspector.convertSharesToPairAssets(
            IOrangeStrykeLPAutomatorState(address(automator)),
            100 ether
        );

        // bob has 95 WETH and 450k USDC (5 WETH and 50k USDC are locked against bob's position)
        assertApproxEqRel(weth, 95 ether, 0.0001e18); // 0.01%
        assertApproxEqRel(usdc, 450_000e6, 0.0001e18); // 0.01%
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

    function _depositFrom(address user, uint256 amount) internal {
        deal(address(WETH), user, amount);
        vm.startPrank(user);
        WETH.approve(address(automator), amount);
        automator.deposit(amount);
        vm.stopPrank();
    }

    function _getQuote(address base, address quote, uint128 baseAmount) internal view returns (uint256) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(_currentTick, baseAmount, base, quote);
    }
}
