// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.t.sol";
// TODO: migrate all utility to this helper functions
import "../helper/AutomatorHelper.t.sol";

contract TestOrangeDopexV2LPAutomatorDeposit is Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_deposit_firstTime() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

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
        vm.expectRevert(OrangeDopexV2LPAutomator.AmountZero.selector);
        automator.deposit(0);
    }

    function test_deposit_revertWhenDepositCapExceeded() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        deal(address(USDCE), alice, 10001e6);

        vm.expectRevert(OrangeDopexV2LPAutomator.DepositCapExceeded.selector);
        vm.prank(alice);
        automator.deposit(10_001e6);
    }

    function test_deposit_revertWhenDepositTooSmall() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        vm.expectRevert(OrangeDopexV2LPAutomator.DepositTooSmall.selector);
        automator.deposit(999999);
    }

    function test_deposit_deductedPerfFee_firstDeposit() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        // set deposit fee to 0.1%, set bob as recipient
        automator.setDepositFeePips(bob, 1000);

        // fee:  9999999 (9999999000 * 0.1%)

        // alice deposits 10_000e6
        uint256 _shares = _depositFrom(alice, 10_000e6);

        assertEq(_shares, 9989999001);
        assertEq(automator.balanceOf(alice), 9989999001);
        assertEq(automator.balanceOf(bob), 9999999);
    }

    function test_deposit_deductedPerfFee_secondDeposit() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        // set deposit fee to 0.1%, set bob as recipient
        automator.setDepositFeePips(bob, 1000);

        // alice deposits 10_000e6
        _depositFrom(alice, 10_000e6);

        // carol deposits 10_000e6
        // fee: 10000000 (10000000000 * 0.1%) from second deposit, no dead shares exist
        uint256 _shares = _depositFrom(carol, 10_000e6);
        assertEq(_shares, 9990000000);
    }
}
