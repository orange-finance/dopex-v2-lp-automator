// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";

/* solhint-disable func-name-mixedcase */
contract TestOrangeStrykeLPAutomatorV2_1Setter is WETH_USDC_Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_setOwner() public {
        address newOwner = makeAddr("setter.newOwner");

        assertEq(automator.isOwner(newOwner), false);

        automator.setOwner(newOwner, true);
        assertEq(automator.isOwner(newOwner), true);

        automator.setOwner(newOwner, false);
        assertEq(automator.isOwner(newOwner), false);
    }

    function test_setStrategist() public {
        address newStrategist = makeAddr("setter.newStrategist");

        assertEq(automator.isStrategist(newStrategist), false);

        automator.setStrategist(newStrategist, true);
        assertEq(automator.isStrategist(newStrategist), true);

        automator.setStrategist(newStrategist, false);
        assertEq(automator.isStrategist(newStrategist), false);
    }

    function test_setDepositCap() public {
        assertNotEq(automator.depositCap(), 100 ether);

        automator.setDepositCap(100 ether);
        assertEq(automator.depositCap(), 100 ether);
    }

    function test_setDepositFeePips() public {
        assertNotEq(automator.depositFeeRecipient(), alice);
        assertNotEq(automator.depositFeePips(), 999);

        automator.setDepositFeePips(alice, 999);

        assertEq(automator.depositFeePips(), 999);
        assertEq(automator.depositFeeRecipient(), alice);

        automator.setDepositFeePips(bob, 1234);

        assertEq(automator.depositFeePips(), 1234);
        assertEq(automator.depositFeeRecipient(), bob);
    }

    function test_setProxyWhitelist() public {
        assertEq(WETH.allowance(address(automator), alice), 0);

        automator.setProxyWhitelist(alice, true);

        assertEq(WETH.allowance(address(automator), alice), type(uint256).max);

        automator.setProxyWhitelist(alice, false);

        assertEq(WETH.allowance(address(automator), alice), 0);
    }

    function test_setProxyWhitelist_ProxyAlreadyWhitelisted() public {
        automator.setProxyWhitelist(alice, true);

        assertEq(WETH.allowance(address(automator), alice), type(uint256).max);

        vm.expectRevert(IOrangeStrykeLPAutomatorV2.ProxyAlreadyWhitelisted.selector);
        automator.setProxyWhitelist(alice, true);
    }

    function test_setter_Unauthorized() public {
        vm.startPrank(makeAddr("prankster"));

        expectUnauthorized();
        automator.setOwner(alice, true);

        expectUnauthorized();
        automator.setStrategist(alice, true);

        expectUnauthorized();
        automator.setDepositCap(100 ether);

        expectUnauthorized();
        automator.setDepositFeePips(alice, 999);

        expectUnauthorized();
        automator.setProxyWhitelist(alice, true);

        vm.stopPrank();
    }

    // solhint-disable-next-line private-vars-leading-underscore
    function expectUnauthorized() internal {
        vm.expectRevert(IOrangeStrykeLPAutomatorV2.Unauthorized.selector);
    }
}
