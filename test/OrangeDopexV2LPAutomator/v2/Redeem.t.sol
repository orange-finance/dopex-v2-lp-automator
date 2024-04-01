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

    uint256 public arbFork;

    function setUp() public override {
        arbFork = vm.createSelectFork("arb");
    }

    // skipping this test on pre-commit
    function test_redeemWithAggregator_dynamic_Skip() public {
        super.setUp();
        uint256 shares = aHandler.deposit(50 ether, alice);
        uint256 usdc = automator.pool().getQuote(address(WETH), address(USDC), 50 ether);
        dealUsdc(address(automator), usdc);

        // (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator), usdc);
        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator), usdc);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator)));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator)));
        emit log_named_uint("alice weth before: ", WETH.balanceOf(alice));

        bytes memory redeemData = abi.encode(kyberswapProxy, router, swapCalldata);

        aHandler.redeem(shares, redeemData, alice);

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator))); // prettier-ignore
        emit log_named_uint("alice weth after: ", WETH.balanceOf(alice));

        uint256 expectedWeth = 50 ether + automator.pool().getQuote(address(USDC), address(WETH), uint128(usdc));

        assertApproxEqRel(expectedWeth, WETH.balanceOf(alice), 0.001e18);
    }

    function test_redeemWithAggregator_hasPositions_dynamic_Skip() public {
        super.setUp();
        uint256 shares = aHandler.deposit(50 ether, alice);
        // uint256 usdc = automator.pool().getQuote(address(WETH), address(USDC), 50 ether);
        dealUsdc(address(automator), 100_000e6);

        aHandler.rebalanceSingleLeft(pool.currentLower() - 10, 30_000e6);
        aHandler.rebalanceSingleLeft(pool.currentLower() - 20, 30_000e6);

        // swap all free usdc when redeeming
        (, uint256 free1) = inspector.freePoolPositionInToken01(automator);
        uint256 freeUsdc = USDC.balanceOf(address(automator)) + free1;
        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator), freeUsdc);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator)));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator)));
        emit log_named_uint("alice weth before: ", WETH.balanceOf(alice));

        bytes memory redeemData = abi.encode(kyberswapProxy, router, swapCalldata);

        aHandler.redeem(shares, redeemData, alice);

        uint256 expectedWeth = 50 ether + automator.pool().getQuote(address(USDC), address(WETH), uint128(freeUsdc));

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator))); // prettier-ignore
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

        emit log_named_uint("block: ", block.number);
        emit log_named_string("buildSwapData.amountUsdc: ", Strings.toString(amountUsdc));
        emit log_named_bytes("swapCalldata: ", swapCalldata);
    }
}
