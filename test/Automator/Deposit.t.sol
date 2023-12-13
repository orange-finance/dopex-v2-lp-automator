// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.sol";

contract TestAutomatorDeposit is Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_deposit_firstTime() public {
        _deployAutomator({
            admin: address(this),
            strategist: address(this),
            pool_: pool,
            asset: USDCE,
            minDepositAssets: 1e6,
            depositCap: 10000e6
        });

        uint256 _shares = _depositFrom(alice, 10000e6);

        // dead shares (1e3) are deducted
        assertEq(_shares, 9999999000);
    }

    function test_deposit_secondTime() public {
        _depositFrom(alice, 10 ether);
        uint256 _shares = _depositFrom(bob, 10 ether);

        // dead shares are deducted
        assertEq(_shares, 10 ether);
    }

    function test_deposit_revertWhenDepositIsZero() public {
        vm.expectRevert(Automator.AmountZero.selector);
        automator.deposit(0);
    }

    function test_deposit_revertWhenDepositCapExceeded() public {
        _deployAutomator({
            admin: address(this),
            strategist: address(this),
            pool_: pool,
            asset: USDCE,
            minDepositAssets: 1e6,
            depositCap: 10_000e6
        });
        deal(address(USDCE), alice, 10001e6);

        vm.expectRevert(Automator.DepositCapExceeded.selector);
        vm.prank(alice);
        automator.deposit(10_001e6);
    }

    function test_deposit_revertWhenDepositTooSmall() public {
        _deployAutomator({
            admin: address(this),
            strategist: address(this),
            pool_: pool,
            asset: USDCE,
            minDepositAssets: 1e6,
            depositCap: 10_000e6
        });

        vm.expectRevert(Automator.DepositTooSmall.selector);
        automator.deposit(999999);
    }
}
