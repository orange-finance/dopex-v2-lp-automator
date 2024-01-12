// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.t.sol";

contract TestOrangeDopexV2LPAutomatorWithdraw is Fixture {
    IERC20 constant ARB = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);

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
        deal(address(USDCE), address(automator), 1000e6);

        vm.expectRevert(OrangeDopexV2LPAutomator.TokenNotPermitted.selector);
        automator.withdraw(WETH);

        vm.expectRevert(OrangeDopexV2LPAutomator.TokenNotPermitted.selector);
        automator.withdraw(USDCE);
    }
}
