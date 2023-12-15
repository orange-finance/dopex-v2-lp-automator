// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IOrangeVaultRegistry} from "../../contracts/vendor/orange/IOrangeVaultRegistry.sol";
import {OrangeDopexV2LPAutomatorV1Factory, OrangeDopexV2LPAutomator, IUniswapV3Pool, IERC20} from "../../contracts/OrangeDopexV2LPAutomatorV1Factory.sol";
import {DopexV2Helper} from "../helper/DopexV2Helper.sol";
import {AutomatorHelper} from "../helper/AutomatorHelper.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract TestOrangeDopexV2LPAutomatorFactory is Test {
    IOrangeVaultRegistry constant REGISTRY = IOrangeVaultRegistry(0x703100b7E538E6B911146F0BC8DD162D77aD7AB2);
    IUniswapV3Pool WETH_USDCE_500 = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.createSelectFork("arb", 160260449);
    }

    function test_createOrangeDopexV2LPAutomator_roleGranted() public {
        vm.prank(alice);
        OrangeDopexV2LPAutomatorV1Factory factory = new OrangeDopexV2LPAutomatorV1Factory(REGISTRY);

        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), alice));
        assertFalse(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), bob));
    }

    function test_createOrangeDopexV2LPAutomator_onlyInit() public {
        vm.prank(alice);
        OrangeDopexV2LPAutomatorV1Factory factory = new OrangeDopexV2LPAutomatorV1Factory(REGISTRY);

        _grantVaultDeployerRoleFromRegistry(address(factory));

        vm.prank(alice);
        OrangeDopexV2LPAutomator automator = factory.createOrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomatorV1Factory.InitArgs({
                admin: alice,
                manager: DopexV2Helper.DOPEX_V2_POSITION_MANAGER,
                handler: DopexV2Helper.DOPEX_UNIV3_HANDLER,
                router: AutomatorHelper.ROUTER,
                pool: WETH_USDCE_500,
                asset: USDCE,
                minDepositAssets: 100e6
            })
        );

        assertEq(address(automator.manager()), address(DopexV2Helper.DOPEX_V2_POSITION_MANAGER));
        assertEq(address(automator.handler()), address(DopexV2Helper.DOPEX_UNIV3_HANDLER));
        assertEq(address(automator.router()), address(AutomatorHelper.ROUTER));
        assertEq(address(automator.pool()), address(WETH_USDCE_500));
        assertEq(address(automator.asset()), address(USDCE));
        assertEq(automator.minDepositAssets(), 100e6);
    }

    function test_createOrangeDopexV2LPAutomator_revertNotAdmin() public {
        vm.prank(alice);
        OrangeDopexV2LPAutomatorV1Factory factory = new OrangeDopexV2LPAutomatorV1Factory(REGISTRY);

        _grantVaultDeployerRoleFromRegistry(address(factory));

        vm.expectRevert();
        vm.prank(bob);
        factory.createOrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomatorV1Factory.InitArgs({
                admin: bob,
                manager: DopexV2Helper.DOPEX_V2_POSITION_MANAGER,
                handler: DopexV2Helper.DOPEX_UNIV3_HANDLER,
                router: AutomatorHelper.ROUTER,
                pool: WETH_USDCE_500,
                asset: USDCE,
                minDepositAssets: 100e6
            })
        );
    }

    function _grantVaultDeployerRoleFromRegistry(address deployer) internal {
        vm.prank(_registryAdmin());
        IAccessControl(address(REGISTRY)).grantRole(keccak256("VAULT_DEPLOYER_ROLE"), deployer);
    }

    function _registryAdmin() internal view returns (address) {
        return IAccessControlEnumerable(address(REGISTRY)).getRoleMember(0x00, 0);
    }
}
