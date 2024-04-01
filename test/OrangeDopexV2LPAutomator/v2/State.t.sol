// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/* solhint-disable func-name-mixedcase */
contract TestAutomatorV2State is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_totalAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDC = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        deal(address(USDC), address(automator), _balanceUSDC);

        uint256 _expected = _balanceWETH + pool.getQuote(address(USDC), address(WETH), uint128(_balanceUSDC));

        assertApproxEqRel(automator.totalAssets(), _expected, 0.0001e18);
    }

    function test_totalAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1000 ether);
        deal(address(USDC), address(automator), 1_000_000e6);

        int24 ct = pool.currentLower();
        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 10, 250 ether);
        aHandler.rebalanceSingleRight(ct + 20, 250 ether);

        assertApproxEqRel(
            automator.totalAssets(),
            1000 ether + pool.getQuote(address(USDC), address(WETH), 1_000_000e6),
            0.001e18
        );
    }

    function test_convertToAssets_noDopexPosition() public {
        aHandler.deposit(100 ether, alice);
        aHandler.deposit(200 ether, bob);

        deal(address(USDC), address(automator), 300_000e6);

        assertApproxEqRel(
            automator.convertToAssets(automator.balanceOf(alice)),
            (100 ether - 1e15) + pool.getQuote(address(USDC), address(WETH), 100_000e6),
            0.0001e18
        );
        assertApproxEqRel(
            automator.convertToAssets(automator.balanceOf(bob)),
            200 ether + pool.getQuote(address(USDC), address(WETH), 200_000e6),
            0.0001e18
        );
    }

    function test_convertToAssets_hasDopexPositions() public {
        aHandler.deposit(100 ether, alice);
        aHandler.deposit(200 ether, bob);

        deal(address(USDC), address(automator), 900_000e6);

        int24 ct = pool.currentLower();
        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 10, 100 ether);
        aHandler.rebalanceSingleRight(ct + 20, 200 ether);

        assertApproxEqRel(
            automator.convertToAssets(automator.balanceOf(alice)),
            (100 ether - 1e15) + pool.getQuote(address(USDC), address(WETH), 300_000e6),
            0.0001e18
        );
        assertApproxEqRel(
            automator.convertToAssets(automator.balanceOf(bob)),
            200 ether + pool.getQuote(address(USDC), address(WETH), 600_000e6),
            0.0001e18
        );
    }

    function test_convertToShares_noDopexPosition() public {
        aHandler.deposit(100 ether, alice);
        aHandler.deposit(200 ether, bob);

        deal(address(USDC), address(automator), 300_000e6);

        assertApproxEqRel(
            automator.convertToShares(100 ether + pool.getQuote(address(USDC), address(WETH), 100_000e6)),
            automator.balanceOf(alice),
            0.0001e18
        );
        assertApproxEqRel(
            automator.convertToShares(200 ether + pool.getQuote(address(USDC), address(WETH), 200_000e6)),
            automator.balanceOf(bob),
            0.0001e18
        );
    }

    function test_convertToShares_hasDopexPositions() public {
        aHandler.deposit(100 ether, alice);
        aHandler.deposit(200 ether, bob);

        deal(address(USDC), address(automator), 900_000e6);

        int24 ct = pool.currentLower();
        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 10, 100 ether);
        aHandler.rebalanceSingleRight(ct + 20, 200 ether);

        assertApproxEqRel(
            automator.convertToShares(100 ether + pool.getQuote(address(USDC), address(WETH), 300_000e6)),
            automator.balanceOf(alice),
            0.0001e18
        );

        assertApproxEqRel(
            automator.convertToShares(200 ether + pool.getQuote(address(USDC), address(WETH), 600_000e6)),
            automator.balanceOf(bob),
            0.0001e18
        );
    }

    function test_getActiveTicks() public {
        harness.pushActiveTick(10);
        harness.pushActiveTick(20);
        harness.pushActiveTick(30);

        int24[] memory at = harness.getActiveTicks();

        assertEq(at.length, 3);
        assertEq(at[0], 10);
        assertEq(at[1], 20);
        assertEq(at[2], 30);
    }
}