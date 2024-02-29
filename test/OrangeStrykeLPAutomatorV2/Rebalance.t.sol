// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {Test, stdJson} from "forge-std/Test.sol";

import {WETH_USDC_OrangeStrykeLPAutomatorV2Harness} from "./OrangeStrykeLPAutomatorV2Harness.sol";
import {IOrangeStrykeLPAutomatorV2} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin//contracts/utils/Strings.sol";

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

    function test_rebalance_flashLoanAndSwap_Skip() public {
        automator.deposit(100 ether, alice);

        (address router, bytes memory swapCallData) = _buildSwapData(address(automator.automator()), 50);

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
}
