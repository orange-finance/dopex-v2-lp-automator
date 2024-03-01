// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {Test, stdJson} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin//contracts/utils/Strings.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {WETH_USDC_OrangeStrykeLPAutomatorV2Harness} from "./OrangeStrykeLPAutomatorV2Harness.sol";
import {IOrangeStrykeLPAutomatorV2} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV2.sol";
import {IBalancerVault} from "./../../contracts/vendor/balancer/IBalancerVault.sol";
import {IBalancerFlashLoanRecipient} from "./../../contracts/vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {UniswapV3Helper} from "../helper/UniswapV3Helper.t.sol";

contract Fixture is Test {
    using stdJson for string;

    WETH_USDC_OrangeStrykeLPAutomatorV2Harness public automator;

    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function setUp() public virtual {
        vm.createSelectFork("arb");
        automator = new WETH_USDC_OrangeStrykeLPAutomatorV2Harness(0, 10000 ether);

        vm.label(address(this), "RebalanceTest");
        vm.label(address(automator), "AutomatorHarness");
        vm.label(balancer, "BalancerVault");
        vm.label(weth, "WETH");
        vm.label(usdc, "USDC");
    }
}

contract TestOrangeStrykeLPAutomatorV2Rebalance is Fixture {
    using UniswapV3Helper for IUniswapV3Pool;

    function setUp() public override {
        super.setUp();
    }

    function test_rebalance_flashLoanAndSwap_Skip() public {
        automator.deposit(100 ether, alice);

        (address router, bytes memory swapCalldata) = _buildSwapData(address(automator.automator()), 50);

        emit log_named_uint("vault weth balance before: ", IERC20(weth).balanceOf(address(automator.automator())));
        emit log_named_uint("vault usdc balance before: ", IERC20(usdc).balanceOf(address(automator.automator())));

        uint256 estUsdc = automator.automator().pool().getQuote(weth, usdc, 50 ether);

        emit log_named_uint("estUsdc: ", estUsdc);

        emit log_named_address("automator harness address: ", address(automator));
        emit log_named_address("automator address: ", address(automator.automator()));

        _expectFlashLoanCall(usdc, estUsdc, router, swapCalldata, new bytes[](0), new bytes[](0));

        automator.rebalance(
            "[]",
            "[]",
            router,
            swapCalldata,
            IOrangeStrykeLPAutomatorV2.RebalanceShortage({token: IERC20(usdc), shortage: estUsdc})
        );

        emit log_named_uint("vault weth balance after: ", IERC20(weth).balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", IERC20(usdc).balanceOf(address(automator.automator()))); // prettier-ignore
    }

    function _buildSwapData(
        address sender,
        uint256 amount
    ) internal returns (address router, bytes memory swapCalldata) {
        string[] memory buildSwapData = new string[](10);
        buildSwapData[0] = "node";
        buildSwapData[1] = "test/OrangeStrykeLPAutomatorV2/kyberswap.mjs";
        buildSwapData[2] = "-i";
        buildSwapData[3] = "weth";
        buildSwapData[4] = "-o";
        buildSwapData[5] = "usdc";
        buildSwapData[6] = "-a";
        buildSwapData[7] = Strings.toString(amount);
        buildSwapData[8] = "-s";
        buildSwapData[9] = Strings.toHexString(uint256(uint160(sender)));

        bytes memory swapData = vm.ffi(buildSwapData);
        (router, swapCalldata) = abi.decode(swapData, (address, bytes));
    }

    function _expectFlashLoanCall(
        address borrowToken,
        uint256 amount,
        address router,
        bytes memory swapCalldata,
        bytes[] memory mintCalldataBatch,
        bytes[] memory burnCalldataBatch
    ) internal {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = IERC20(borrowToken);
        amounts[0] = amount;
        IOrangeStrykeLPAutomatorV2.FlashLoanUserData memory ud = IOrangeStrykeLPAutomatorV2.FlashLoanUserData({
            router: router,
            swapCalldata: swapCalldata,
            mintCalldata: mintCalldataBatch,
            burnCalldata: burnCalldataBatch
        });
        bytes memory flashLoanCall = abi.encodeCall(
            IBalancerVault.flashLoan,
            (IBalancerFlashLoanRecipient(address(automator.automator())), tokens, amounts, abi.encode(ud))
        );

        emit log_named_bytes("expect call bytes", flashLoanCall);
        vm.expectCall(balancer, flashLoanCall);
    }
}
