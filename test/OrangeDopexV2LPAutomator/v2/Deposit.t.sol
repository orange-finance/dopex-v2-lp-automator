// SPDX-License-Identifier: GPL-3.0

/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.19;

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

contract TestAutomatorV2Deposit is WETH_USDC_Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();
    }

    function test_deposit_receivingFee() public {
        automator.setDepositFeePips(alice, 1e3); // 0.1% fee to alice

        aHandler.deposit(100 ether, bob);

        // deposit fee is subtracted from bob's deposit
        assertEq(automator.balanceOf(bob), FullMath.mulDiv((100 ether - 1e15), 1e6 - 1e3, 1e6));
        // alice receives the fee
        assertEq(automator.balanceOf(alice), FullMath.mulDiv((100 ether - 1e15), 1e3, 1e6));
    }
}
