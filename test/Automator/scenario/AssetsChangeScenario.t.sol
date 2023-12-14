// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {AutomatorHelper} from "../../helper/AutomatorHelper.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Automator, IAutomator} from "../../../contracts/Automator.sol";

/**
 * Test scenario:
 *
 * position | locked | tick_position | price | user_action | strategist_action
 * some     | none   | below         | t1up  | none        | mint
 * some     | some   | above         | t0up  | deposit     | mint
 * full     | none   | above         | stay  | redeem      | burn
 * some     | full   | none          | stay  | deposit     | none
 * none     | none   | none          | t0up  | redeem      | mint
 * full     | some   | both          | t0up  | none        | burn
 * full     | some   | below         | stay  | none        | burn & mint
 * some     | some   | below         | t1up  | redeem      | burn & mint
 * full     | none   | both          | t1up  | deposit     | burn & mint
 * full     | some   | none          | t1up  | none        | burn
 * none     | none   | both          | stay  | redeem      | mint
 * some     | full   | none          | t1up  | none        | none
 * some     | none   | both          | t0up  | deposit     | burn
 * full     | none   | above         | t1up  | none        | burn & mint
 * none     | none   | below         | t1up  | deposit     | mint
 * some     | full   | none          | t0up  | redeem      | none
 * some     | some   | below         | t0up  | none        | burn
 * some     | some   | none          | stay  | none        | none
 * some     | none   | none          | t0up  | none        | none
 * none     | none   | above         | t1up  | none        | mint
 * full     | some   | none          | t0up  | none        | burn & mint
 */

contract TestScenarioAssetsChange is Test {
    using AutomatorHelper for Automator;
    using UniswapV3Helper for IUniswapV3Pool;

    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IUniswapV3Pool WETH_USDCE_500 = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);

    Automator automator;
    address strategist = makeAddr("mockStrategist");

    function setUp() public {
        vm.createSelectFork("arb", 159926478);
    }

    function test_scenario_1() public {
        /**
         * position | locked | tick_position | price | user_action | strategist_action
         * some     | none   | below         | t1up  | none        | mint
         */

        automator = _deployAutomatorWithInitialDeposit(
            DeployAutomatorWithDeposit({
                depositor: address(this),
                depositAssets: 100_000e6,
                vm: vm,
                admin: address(this),
                strategist: address(this),
                pool: WETH_USDCE_500,
                asset: USDCE,
                minDepositAssets: 100e6,
                depositCap: 100_000e6
            })
        );

        // current tick: -199137
        IAutomator.RebalanceTickInfo[] memory _ticksMint = new IAutomator.RebalanceTickInfo[](3);
        _ticksMint[0] = IAutomator.RebalanceTickInfo({tick: -199200, liquidity: 84592119769033773}); // 2000 USDCE
        _ticksMint[1] = IAutomator.RebalanceTickInfo({tick: -199300, liquidity: 127524177421952416}); // 3000 USDCE
        _ticksMint[2] = IAutomator.RebalanceTickInfo({tick: -199350, liquidity: 170457827642008742}); // 4000 USDCE
        automator.rebalanceMint(_ticksMint);

        // change tick to => -199181
        _wethToUsdce(323 ether);

        _ticksMint = new IAutomator.RebalanceTickInfo[](5);
        _ticksMint[0] = IAutomator.RebalanceTickInfo({tick: -199200, liquidity: 46990922531698261}); // 1111 USDCE
        _ticksMint[1] = IAutomator.RebalanceTickInfo({tick: -199300, liquidity: 94452907410526089}); // 2222 USDCE
        _ticksMint[2] = IAutomator.RebalanceTickInfo({tick: -199350, liquidity: 142033984882703784}); // 3333 USDCE
        _ticksMint[3] = IAutomator.RebalanceTickInfo({tick: -199430, liquidity: 190137640122548586}); // 4444 USDCE
        _ticksMint[4] = IAutomator.RebalanceTickInfo({tick: -199440, liquidity: 237790909947844180}); // 5555 USDCE

        automator.rebalanceMint(_ticksMint);

        // allow 1% error rate (token used less then calculated)
        // 100_000e6 - 2000e6 - 3000e6 - 4000e6 - 1111e6 - 2222e6 - 3333e6 - 4444e6 - 5555e6 = 74_444e6
        assertLt(USDCE.balanceOf(address(automator)), 74_444e6);
        assertApproxEqRel(USDCE.balanceOf(address(automator)), 74_444e6, 0.01e18);
    }

    struct DeployAutomatorWithDeposit {
        Vm vm;
        address admin;
        address strategist;
        IUniswapV3Pool pool;
        IERC20 asset;
        uint256 minDepositAssets;
        uint256 depositCap;
        address depositor;
        uint256 depositAssets;
    }

    function _deployAutomatorWithInitialDeposit(DeployAutomatorWithDeposit memory params) public returns (Automator) {
        Automator _automator = AutomatorHelper.deployAutomator({
            vm: vm,
            dopexV2ManagerOwner: DopexV2Helper.DOPEX_V2_MANAGER_OWNER,
            admin: params.admin,
            strategist: params.strategist,
            manager: DopexV2Helper.DOPEX_V2_POSITION_MANAGER,
            uniV3Handler: DopexV2Helper.uniV3Handler,
            router: AutomatorHelper.ROUTER,
            pool: params.pool,
            asset: params.asset,
            minDepositAssets: params.minDepositAssets,
            depositCap: params.depositCap
        });

        deal(address(params.asset), params.depositor, params.depositAssets);
        vm.startPrank(params.depositor);
        params.asset.approve(address(_automator), params.depositAssets);
        _automator.deposit(params.depositAssets);
        vm.stopPrank();

        return _automator;
    }

    function _wethToUsdce(uint256 wethAmount) internal {
        deal(address(WETH), address(this), wethAmount);
        WETH.approve(address(AutomatorHelper.ROUTER), wethAmount);
        UniswapV3Helper.exactInputSingleSwap(
            AutomatorHelper.ROUTER,
            address(WETH),
            address(USDCE),
            500,
            wethAmount,
            0,
            0
        );
    }
}
