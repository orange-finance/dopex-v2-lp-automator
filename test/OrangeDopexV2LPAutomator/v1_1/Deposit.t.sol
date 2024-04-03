// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, contract-name-camelcase */
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {auto11} from "../../helper/AutomatorHelperV1_1.t.sol";
import {ChainlinkQuoter} from "./../../../contracts/ChainlinkQuoter.sol";
import {OrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/OrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/IOrangeStrykeLPAutomatorV1_1.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestOrangeStrykeLPAutomatorV1_1Deposit is WETH_USDC_Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
    }

    function test_deposit_firstTime() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        uint256 _shares = _depositFrom(alice, 10000e6);

        // dead shares (1e3) are deducted
        assertEq(_shares, 9999999000);
    }

    function test_deposit_secondTime() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 20 ether
            })
        );

        _depositFrom(alice, 10 ether);
        uint256 _shares = _depositFrom(bob, 10 ether);

        // dead shares are deducted
        assertEq(_shares, 10 ether);
    }

    function test_deposit_revertWhenDepositIsZero() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.AmountZero.selector);
        automator.deposit(0);
    }

    function test_deposit_revertWhenDepositCapExceeded() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        deal(address(USDC), alice, 10_001e6);

        _depositFrom(alice, 5_000e6);

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.DepositCapExceeded.selector);
        automator.deposit(5_001e6);
    }

    function test_deposit_revertWhenDepositTooSmall() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.DepositTooSmall.selector);
        automator.deposit(999999);
    }

    function test_deposit_deductedPerfFee_firstDeposit() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
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
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 20000e6
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

    function test_initialize_minDepositAssetsTooSmall() public {
        // set to 1 / 1000 of 1e18 will fail
        address impl = address(new OrangeStrykeLPAutomatorV1_1());
        bytes memory initCall = abi.encodeCall(
            OrangeStrykeLPAutomatorV1_1.initialize,
            OrangeStrykeLPAutomatorV1_1.InitArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                quoter: chainlinkQuoter,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: WETH,
                minDepositAssets: 0.001 ether
            })
        );

        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.MinDepositAssetsTooSmall.selector);
        new ERC1967Proxy(impl, initCall);

        // set to 1e6 (100% in pip) - 1 will fail
        impl = address(new OrangeStrykeLPAutomatorV1_1());
        initCall = abi.encodeCall(
            OrangeStrykeLPAutomatorV1_1.initialize,
            OrangeStrykeLPAutomatorV1_1.InitArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                quoter: chainlinkQuoter,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: WETH,
                minDepositAssets: 999999
            })
        );
        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.MinDepositAssetsTooSmall.selector);
        new ERC1967Proxy(impl, initCall);
    }

    function test_deposit_sharesRoundedToZero() public {
        automator = auto11.deploy({
            args: auto11.DeployArgs({
                dopexV2ManagerOwner: managerOwner,
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 20_000_000_001e6
            })
        });

        // alice deposits 10_000e6
        _depositFrom(alice, 10_000e6);

        // assume that vault earned 10 billion and one
        deal(address(USDC), address(automator), 10_000_000_001e6);

        // 1 * 10_000e6 / 10_000_000_001e6 = 0
        // this is the quite rare case because the vault has to earn huge amount of profit
        deal(address(USDC), bob, 1e6);
        vm.startPrank(bob);
        USDC.approve(address(automator), 1e6);
        vm.expectRevert(IOrangeStrykeLPAutomatorV1_1.DepositTooSmall.selector);
        automator.deposit(1e6);
        vm.stopPrank();
    }

    function _depositFrom(address account, uint256 amount) internal returns (uint256 shares) {
        IERC20 _asset = automator.asset();
        deal(address(_asset), account, amount);

        vm.startPrank(account);
        _asset.approve(address(automator), amount);
        shares = automator.deposit(amount);
        vm.stopPrank();
    }
}
