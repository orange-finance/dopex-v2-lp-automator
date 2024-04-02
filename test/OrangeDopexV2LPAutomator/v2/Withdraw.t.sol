// SPDX-License-Identifier: GPL-3.0

/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.19;

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOrangeStrykeLPAutomatorV2} from "contracts/v2/IOrangeStrykeLPAutomatorV2.sol";

contract TestAutomatorV2Withdraw is WETH_USDC_Fixture {
    address public constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_withdraw() public {
        // reward 100k ARB to automator
        deal(ARB, address(automator), 100_000e18);

        automator.withdraw(IERC20(ARB));

        assertEq(IERC20(ARB).balanceOf(address(automator)), 0);
        assertEq(IERC20(ARB).balanceOf(address(this)), 100_000e18);
    }

    function test_withdraw_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(IOrangeStrykeLPAutomatorV2.Unauthorized.selector);
        automator.withdraw(IERC20(ARB));
    }

    function test_withdraw_tokenNotPermitted() public {
        vm.expectRevert(IOrangeStrykeLPAutomatorV2.TokenNotPermitted.selector);
        automator.withdraw(IERC20(USDC));

        vm.expectRevert(IOrangeStrykeLPAutomatorV2.TokenNotPermitted.selector);
        automator.withdraw(IERC20(WETH));
    }
}
