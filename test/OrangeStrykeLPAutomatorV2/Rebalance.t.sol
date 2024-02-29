// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {Test, stdJson} from "forge-std/Test.sol";

import {WETH_USDC_OrangeStrykeLPAutomatorV2Harness} from "./OrangeStrykeLPAutomatorV2Harness.sol";
import {IOrangeStrykeLPAutomatorV2} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Fixture is Test {
    using stdJson for string;
    WETH_USDC_OrangeStrykeLPAutomatorV2Harness public automator;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function setUp() public virtual {
        vm.createSelectFork("arb");
        automator = new WETH_USDC_OrangeStrykeLPAutomatorV2Harness(0, 10000 ether);

        vm.label(address(this), "RebalanceTest");
        vm.label(address(automator), "Automator");
    }
}

contract TestOrangeStrykeLPAutomatorV2Rebalance is Fixture {
    function setUp() public override {
        super.setUp();
    }

    function test_automator() public {
        automator.deposit(100 ether, alice);

        assertEq(automator.automator().balanceOf(alice), 99999000000000000000);
    }

    function test_rebalance_flashLoanAndSwap_Skip() public {
        automator.deposit(100 ether, alice);

        // get swap data
        // string[] memory buildSwapData = stdJson.readStringArray(
        //     // solhint-disable-next-line quotes
        //     '["node", "test/OrangeStrykeLPAutomatorV2/kyberswap.mjs", "-i", "weth", "-o", "usdc", "-a", 50, "-s", "0xb0c757bC94704246Ce0552b5Ccc1A547c0633914"]',
        //     "."
        // );
        string[] memory buildSwapData = stdJson.readStringArray(
            string.concat(
                "node",
                "test/OrangeStrykeLPAutomatorV2/kyberswap.mjs",
                "-i",
                "weth",
                "-o",
                "usdc",
                "-a",
                "50",
                "-s",
                // TODO: replace with actual automator address
                // ? how to convert address to string
                "<automator-address>"
            ),
            "."
        );
        bytes memory swapData = vm.ffi(buildSwapData);

        (address router, bytes memory swapCallData) = abi.decode(swapData, (address, bytes));

        emit log_named_uint("vault weth balance before: ", IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance before: ", IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(address(automator.automator()))); // prettier-ignore

        // TODO: expectCall to flashLoan

        // TODO: calculate shortage and pass it to the rebalance function
        automator.rebalance(
            "[]",
            "[]",
            router,
            swapCallData,
            IOrangeStrykeLPAutomatorV2.RebalanceShortage({
                token: IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
                shortage: 0
            })
        );

        emit log_named_uint("vault weth balance after: ", IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(address(automator.automator()))); // prettier-ignore
    }
}
