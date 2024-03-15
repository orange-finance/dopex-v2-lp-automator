// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {DealExtension} from "../../helper/DealExtension.t.sol";

contract TestOrangeStrykeLPAutomatorV2Redeem is WETH_USDC_Fixture, DealExtension {
    using UniswapV3Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 190518091);
        super.setUp();
    }

    function test_redeemWithAggregator_Skip() public {
        uint256 shares = automator.deposit(50 ether, alice);
        uint256 usdc = automator.automator().pool().getQuote(address(WETH), address(USDC), 50 ether);
        dealUsdc(address(automator.automator()), usdc);

        // (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator.automator()), usdc);
        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator.automator()), usdc);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator.automator())));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator.automator())));
        emit log_named_uint("alice weth before: ", WETH.balanceOf(alice));

        bytes memory redeemData = abi.encode(kyberswapProxy, router, swapCalldata);

        automator.redeem(shares, redeemData, alice);

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("alice weth after: ", WETH.balanceOf(alice));

        uint256 expectedWeth = 50 ether +
            automator.automator().pool().getQuote(address(USDC), address(WETH), uint128(usdc));

        assertApproxEqRel(expectedWeth, WETH.balanceOf(alice), 0.001e18);
    }

    function test_redeemWithAggregator_hasPositions_Skip() public {
        uint256 shares = automator.deposit(50 ether, alice);
        // uint256 usdc = automator.automator().pool().getQuote(address(WETH), address(USDC), 50 ether);
        dealUsdc(address(automator.automator()), 100_000e6);

        automator.rebalanceSingleLeft(pool.currentLower() - 10, 30_000e6);
        automator.rebalanceSingleLeft(pool.currentLower() - 20, 30_000e6);

        // swap all free usdc when redeeming
        (, uint256 free1) = inspector.freePoolPositionInToken01(automator.automator());
        uint256 freeUsdc = USDC.balanceOf(address(automator.automator())) + free1;
        // (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator.automator()), freeUsdc);
        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(kyberswapProxy), freeUsdc);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator.automator())));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator.automator())));
        emit log_named_uint("alice weth before: ", WETH.balanceOf(alice));

        bytes memory redeemData = abi.encode(kyberswapProxy, router, swapCalldata);

        automator.redeem(shares, redeemData, alice);

        uint256 expectedWeth = 50 ether +
            automator.automator().pool().getQuote(address(USDC), address(WETH), uint128(freeUsdc));

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("alice weth after: ", WETH.balanceOf(alice));

        assertApproxEqRel(expectedWeth, WETH.balanceOf(alice), 0.001e18);
    }

    function _buildKyberswapData(
        address sender,
        uint256 amountUsdc
    ) internal returns (address router, bytes memory swapCalldata) {
        string[] memory buildSwapData = new string[](12);
        buildSwapData[0] = "node";
        buildSwapData[1] = "test/OrangeDopexV2LPAutomator/v2/kyberswap.mjs";
        buildSwapData[2] = "-i";
        buildSwapData[3] = "usdc";
        buildSwapData[4] = "-o";
        buildSwapData[5] = "weth";
        buildSwapData[6] = "-u";
        buildSwapData[7] = "wei";
        buildSwapData[8] = "-a";
        buildSwapData[9] = Strings.toString(amountUsdc);
        buildSwapData[10] = "-s";
        buildSwapData[11] = Strings.toHexString(uint256(uint160(sender)));

        bytes memory swapData = vm.ffi(buildSwapData);
        (router, swapCalldata) = abi.decode(swapData, (address, bytes));
    }
}
