// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

contract TestOrangeStrykeLPAutomatorV2Redeem is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_redeem_noPositions() public {
        aHandler.deposit(100 ether, alice);

        assertEq(automator.balanceOf(alice), 100 ether - 1e15);
        assertEq(WETH.balanceOf(alice), 0);

        aHandler.redeem(100 ether - 1e15, "", alice);

        assertEq(automator.balanceOf(alice), 0);
        assertEq(WETH.balanceOf(alice), 100 ether - 1e15);
    }

    function test_redeem_hasCounterAssets() public {
        aHandler.deposit(100 ether, alice);

        assertEq(automator.balanceOf(alice), 100 ether - 1e15);
        assertEq(WETH.balanceOf(alice), 0);

        deal(address(USDC), address(automator), 1_000_000e6);

        aHandler.redeemWithMockSwap(100 ether - 1e15, alice);

        assertEq(automator.balanceOf(alice), 0);
        assertApproxEqRel(
            WETH.balanceOf(alice),
            100 ether - 1e15 + pool.getQuote(address(USDC), address(WETH), 1_000_000e6),
            0.005e18
        );
    }

    function test_redeem_hasPositions() public {
        aHandler.deposit(100 ether, alice);

        assertEq(automator.balanceOf(alice), 100 ether - 1e15);
        assertEq(WETH.balanceOf(alice), 0);

        deal(address(USDC), address(automator), 1_000_000e6);

        int24 ct = pool.currentLower();

        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 20, 25 ether);
        aHandler.rebalanceSingleRight(ct + 30, 25 ether);

        aHandler.redeemWithMockSwap(100 ether - 1e15, alice);

        assertEq(automator.balanceOf(alice), 0);
        assertApproxEqRel(
            WETH.balanceOf(alice),
            100 ether - 1e15 + pool.getQuote(address(USDC), address(WETH), 1_000_000e6),
            0.005e18
        );
    }

    function test_redeem_hasLockedPositions() public {
        aHandler.deposit(100 ether, alice);

        assertEq(automator.balanceOf(alice), 100 ether - 1e15);
        assertEq(WETH.balanceOf(alice), 0);

        deal(address(USDC), address(automator), 1_000_000e6);

        int24 ct = pool.currentLower();

        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 20, 25 ether);
        aHandler.rebalanceSingleRight(ct + 30, 25 ether);

        pool.useDopexPosition(address(0), ct - 20, pool.freeLiquidityOfTick(address(0), ct - 20));
        pool.useDopexPosition(address(0), ct + 30, pool.freeLiquidityOfTick(address(0), ct + 30));

        aHandler.redeemWithMockSwap(100 ether - 1e15, alice);

        assertEq(automator.balanceOf(alice), 0);
        assertApproxEqRel(
            WETH.balanceOf(alice),
            75 ether + pool.getQuote(address(USDC), address(WETH), 750_000e6),
            0.005e18
        );
    }

    function test_redeem_hasReservedPositions() public {
        aHandler.deposit(100 ether, alice);

        assertEq(automator.balanceOf(alice), 100 ether - 1e15);
        assertEq(WETH.balanceOf(alice), 0);

        deal(address(USDC), address(automator), 1_000_000e6);

        int24 ct = pool.currentLower();

        aHandler.rebalanceSingleLeft(ct - 20, 250_000e6);
        aHandler.rebalanceSingleLeft(ct - 10, 250_000e6);
        aHandler.rebalanceSingleRight(ct + 20, 25 ether);
        aHandler.rebalanceSingleRight(ct + 30, 25 ether);

        // mint new positions by bob
        deal(address(USDC), bob, 5_000_000e6);
        vm.prank(bob);
        USDC.approve(address(manager), 5_000_000e6);
        pool.mintDopexPosition(address(0), ct - 20, pool.singleLiqLeft(ct - 20, 5_000_000e6), bob);
        // use positions
        pool.useDopexPosition(address(0), ct - 20, pool.freeLiquidityOfTick(address(0), ct - 20));
        // bob reserves positions to burn
        pool.reserveDopexPosition(address(0), ct - 20, pool.singleLiqLeft(ct - 20, 4_000_000e6), bob);
        // now total liquidity is less than used liquidity. possible to underflow
        assertLt(pool.totalLiquidityOfTick(address(0), ct - 20), pool.usedLiquidityOfTick(address(0), ct - 20));

        // check if redeem works
        aHandler.redeemWithMockSwap(100 ether - 1e15, alice);

        assertEq(automator.balanceOf(alice), 0);
        assertApproxEqRel(
            WETH.balanceOf(alice),
            100 ether + pool.getQuote(address(USDC), address(WETH), 750_000e6),
            0.005e18
        );
    }
}
