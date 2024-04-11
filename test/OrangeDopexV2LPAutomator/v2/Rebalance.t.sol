// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";
import {IOrangeSwapProxy} from "./../../../contracts/v2/IOrangeSwapProxy.sol";
import {IBalancerVault} from "../../../contracts/vendor/balancer/IBalancerVault.sol";
import {IBalancerFlashLoanRecipient} from "../../../contracts/vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract TestOrangeStrykeLPAutomatorV2Rebalance is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    IOrangeStrykeLPAutomatorV2.RebalanceTick[] public mintTicks;
    IOrangeStrykeLPAutomatorV2.RebalanceTick[] public burnTicks;

    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_rebalance_mint_noSwap_single() public {
        aHandler.deposit(100 ether, alice);

        int24 ct = pool.currentLower();

        mintTicks.push(_tickInit(ct + 10, 20 ether, 0));

        aHandler.rebalanceWithMockSwap(mintTicks, burnTicks);

        int24[] memory ticks = automator.getActiveTicks();
        assertEq(ticks.length, 1);

        assertEq(ticks[0], ct + 10);

        assertApproxEqRel(
            pool.dopexLiquidityOf(address(0), address(automator), ticks[0]),
            pool.singleLiqRight(ticks[0], 20 ether),
            0.001e18
        );

        assertApproxEqRel(WETH.balanceOf(address(automator)), 80 ether, 0.001e18);
    }

    function test_rebalance_mintAndBurn() public {
        aHandler.deposit(100 ether, alice);

        deal(address(USDC), address(automator), 1_000_000e6);

        int24 ct = pool.currentLower();

        mintTicks.push(_tickInit(ct - 20, 0, 300_000e6));
        mintTicks.push(_tickInit(ct - 10, 0, 300_000e6));
        mintTicks.push(_tickInit(ct + 10, 20 ether, 0));
        mintTicks.push(_tickInit(ct + 20, 20 ether, 0));

        aHandler.rebalanceWithMockSwap(mintTicks, burnTicks);

        int24[] memory ticks = automator.getActiveTicks();
        assertEq(ticks.length, 4);

        for (uint256 i = 0; i < ticks.length; i++) {
            uint128 liq = pool.dopexLiquidityOf(address(0), address(automator), ticks[i]);
            assertEq(ticks[i], mintTicks[i].tick);
            assertApproxEqRel(liq, mintTicks[i].liquidity, 0.001e18);
        }

        assertApproxEqRel(WETH.balanceOf(address(automator)), 60 ether, 0.001e18);
        assertApproxEqRel(USDC.balanceOf(address(automator)), 400_000e6, 0.001e18);

        delete mintTicks;

        mintTicks.push(_tickInit(ct - 50, 0, 500_000e6));
        mintTicks.push(_tickInit(ct + 50, 70 ether, 0));

        // burn all free liquidity
        burnTicks.push(_tickInit(ct - 20, inspector.getTickFreeLiquidity(automator, ct - 20)));
        burnTicks.push(_tickInit(ct + 20, inspector.getTickFreeLiquidity(automator, ct + 20)));

        // burn some shares
        burnTicks.push(_tickInit(ct - 10, 0, 150_000e6));
        burnTicks.push(_tickInit(ct + 10, 10 ether, 0));

        aHandler.rebalanceWithMockSwap(mintTicks, burnTicks);

        ticks = automator.getActiveTicks();

        assertEq(ticks.length, 4);

        // first minted ticks, partially burned
        // tick order has changed enumerable set's array moves the last element to the deleted index
        assertEq(ticks[0], ct + 10);
        assertApproxEqRel(
            pool.dopexLiquidityOf(address(0), address(automator), ticks[0]),
            pool.singleLiqRight(ticks[0], 10 ether),
            0.001e18
        );
        assertEq(ticks[1], ct - 10);
        assertApproxEqRel(
            pool.dopexLiquidityOf(address(0), address(automator), ticks[1]),
            pool.singleLiqLeft(ticks[1], 150_000e6),
            0.001e18
        );

        // new minted ticks
        assertEq(ticks[2], ct - 50);
        assertApproxEqRel(
            pool.dopexLiquidityOf(address(0), address(automator), ticks[2]),
            pool.singleLiqLeft(ticks[2], 500_000e6),
            0.001e18
        );

        assertEq(ticks[3], ct + 50);
        assertApproxEqRel(
            pool.dopexLiquidityOf(address(0), address(automator), ticks[3]),
            pool.singleLiqRight(ticks[3], 70 ether),
            0.001e18
        );

        assertApproxEqRel(WETH.balanceOf(address(automator)), 20 ether, 0.003e18);
        assertApproxEqRel(USDC.balanceOf(address(automator)), 350_000e6, 0.003e18);
    }

    function test_rebalance_mintAndBurn_flashLoan() public {
        aHandler.deposit(100 ether, alice);

        int24 ct = pool.currentLower();

        mintTicks.push(_tickInit(ct - 20, 0, pool.getQuote(address(WETH), address(USDC), 20 ether)));
        mintTicks.push(_tickInit(ct + 20, 20 ether, 0));

        aHandler.rebalanceWithMockSwap(mintTicks, burnTicks);

        int24[] memory ticks = automator.getActiveTicks();
        assertEq(ticks.length, 2);

        for (uint256 i = 0; i < ticks.length; i++) {
            uint128 liq = pool.dopexLiquidityOf(address(0), address(automator), ticks[i]);
            assertEq(ticks[i], mintTicks[i].tick);
            assertApproxEqRel(liq, mintTicks[i].liquidity, 0.001e18);
        }

        // all WETH are swapped to USDC to mint lower side liquidity
        assertEq(WETH.balanceOf(address(automator)), 0);
        assertApproxEqRel(
            USDC.balanceOf(address(automator)),
            pool.getQuote(address(WETH), address(USDC), 60 ether),
            0.001e18
        );
    }

    function test_rebalance_onlyStrategist() public {
        vm.prank(alice);
        vm.expectRevert(IOrangeStrykeLPAutomatorV2.Unauthorized.selector);
        automator.rebalance(
            mintTicks,
            burnTicks,
            address(0),
            IOrangeSwapProxy.SwapInputRequest({
                provider: address(0),
                swapCalldata: "",
                expectTokenIn: USDC,
                expectTokenOut: WETH,
                expectAmountIn: 1_000_000e6,
                inputDelta: 0
            }),
            ""
        );
    }

    function test_receiveFlashLoan_revertUnauthorized() public {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory feeAmounts = new uint256[](1);
        bytes[] memory mintCalldata = new bytes[](1);
        bytes[] memory burnCalldata = new bytes[](1);
        bytes memory userData = abi.encode(
            IOrangeStrykeLPAutomatorV2.FlashLoanUserData({
                swapProxy: address(0),
                swapRequest: IOrangeSwapProxy.SwapInputRequest({
                    provider: address(0),
                    swapCalldata: "",
                    expectTokenIn: USDC,
                    expectTokenOut: WETH,
                    expectAmountIn: 1_000_000e6,
                    inputDelta: 0
                }),
                mintCalldata: mintCalldata,
                burnCalldata: burnCalldata
            })
        );

        vm.expectRevert(IOrangeStrykeLPAutomatorV2.FlashLoan_Unauthorized.selector);
        vm.prank(address(balancer));
        automator.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
    }

    function _tickInit(
        int24 tickLower,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (IOrangeStrykeLPAutomatorV2.RebalanceTick memory tick) {
        int24 ct = pool.currentTick();
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtRatioAtTick(ct),
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickLower + pool.tickSpacing()),
            amount0,
            amount1
        );

        tick = IOrangeStrykeLPAutomatorV2.RebalanceTick({tick: tickLower, liquidity: uint128(liq)});
    }

    function _tickInit(
        int24 tickLower,
        uint128 liquidity
    ) internal pure returns (IOrangeStrykeLPAutomatorV2.RebalanceTick memory tick) {
        tick = IOrangeStrykeLPAutomatorV2.RebalanceTick({tick: tickLower, liquidity: liquidity});
    }

    function _expectFlashLoanCall(
        address borrowToken,
        uint256 amount,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest memory swapRequest,
        bytes[] memory mintCalldataBatch,
        bytes[] memory burnCalldataBatch
    ) internal {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = IERC20(borrowToken);
        amounts[0] = amount;
        IOrangeStrykeLPAutomatorV2.FlashLoanUserData memory ud = IOrangeStrykeLPAutomatorV2.FlashLoanUserData({
            swapProxy: swapProxy,
            swapRequest: swapRequest,
            mintCalldata: mintCalldataBatch,
            burnCalldata: burnCalldataBatch
        });
        bytes memory flashLoanCall = abi.encodeCall(
            IBalancerVault.flashLoan,
            (IBalancerFlashLoanRecipient(address(automator)), tokens, amounts, abi.encode(ud))
        );

        emit log_named_bytes("expect call bytes", flashLoanCall);
        vm.expectCall(address(balancer), flashLoanCall);
    }
}
