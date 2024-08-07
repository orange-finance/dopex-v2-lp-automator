// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";
import {IOrangeSwapProxy} from "../../../contracts/swap-proxy/IOrangeSwapProxy.sol";
import {IBalancerVault} from "../../../contracts/vendor/balancer/IBalancerVault.sol";
import {IBalancerFlashLoanRecipient} from "../../../contracts/vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";

contract TestOrangeStrykeLPAutomatorV2RebalanceSlow is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;

    uint256 public arbFork;

    function setUp() public override {
        arbFork = vm.createSelectFork("arb");
        super.setUp();
    }

    function test_rebalance_flashLoanAndSwap_dynamic_Skip() public {
        aHandler.deposit(100 ether, alice);

        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator), 50);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator)));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator)));

        uint256 estUsdc = automator.pool().getQuote(address(WETH), address(USDC), 50 ether);

        IOrangeSwapProxy.SwapInputRequest memory req = IOrangeSwapProxy.SwapInputRequest({
            provider: router,
            swapCalldata: swapCalldata,
            expectTokenIn: WETH,
            expectTokenOut: USDC,
            expectAmountIn: 50 ether,
            inputDelta: 5 // 0.05% slippage
        });

        _expectFlashLoanCall(address(USDC), estUsdc, address(kyberswapProxy), req, new bytes[](0), new bytes[](0));

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = estUsdc;

        aHandler.rebalance("[]", "[]", address(kyberswapProxy), req, abi.encode(tokens, amounts, true));

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator))); // prettier-ignore
    }

    function _buildKyberswapData(
        address sender,
        uint256 amount
    ) internal returns (address router, bytes memory swapCalldata) {
        string[] memory buildSwapData = new string[](12);
        buildSwapData[0] = "node";
        buildSwapData[1] = "test/OrangeDopexV2LPAutomator/v2/kyberswap.mjs";
        buildSwapData[2] = "-i";
        buildSwapData[3] = "weth";
        buildSwapData[4] = "-o";
        buildSwapData[5] = "usdc";
        buildSwapData[6] = "-u";
        buildSwapData[7] = "18";
        buildSwapData[8] = "-a";
        buildSwapData[9] = Strings.toString(amount);
        buildSwapData[10] = "-s";
        buildSwapData[11] = Strings.toHexString(uint256(uint160(sender)));

        bytes memory swapData = vm.ffi(buildSwapData);
        (router, swapCalldata) = abi.decode(swapData, (address, bytes));

        emit log_named_uint("block: ", block.number);
        emit log_named_bytes("swapCalldata: ", swapCalldata);
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
