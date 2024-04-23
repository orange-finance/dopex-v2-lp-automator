// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, contract-name-camelcase */
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/IOrangeStrykeLPAutomatorV1_1.sol";

contract TestOrangeStrykeLPAutomatorV1_1Withdraw is WETH_USDC_Fixture {
    IERC20 public constant ARB = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();
    }

    function test_withdraw_arb() public {
        deal(address(ARB), address(automator), 1000e18);
        automator.withdraw(ARB);

        assertEq(ARB.balanceOf(address(automator)), 0);
        assertEq(ARB.balanceOf(address(this)), 1000e18);
    }

    function test_withdraw_revertWhenNotAdmin() public {
        deal(address(ARB), address(automator), 1000e18);

        vm.prank(alice);
        vm.expectRevert();
        automator.withdraw(ARB);
    }

    function test_withdraw_revertWhenTryingToWithdrawFunds() public {
        deal(address(WETH), address(automator), 1000e18);
        deal(address(USDC), address(automator), 1000e6);

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.TokenNotPermitted.selector);
        automator.withdraw(WETH);

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.TokenNotPermitted.selector);
        automator.withdraw(USDC);
    }
}
