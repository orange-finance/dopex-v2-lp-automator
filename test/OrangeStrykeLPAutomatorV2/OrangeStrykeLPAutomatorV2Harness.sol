// SPDX-License-Identifier: GPL-3.0

// solhint-disable-next-line one-contract-per-file
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ChainlinkQuoter} from "./../../contracts/ChainlinkQuoter.sol";
import {IBalancerVault} from "./../../contracts/vendor/balancer/IBalancerVault.sol";

import {IOrangeStrykeLPAutomatorV2} from "./../../contracts/interfaces/IOrangeStrykeLPAutomatorV2.sol";
import {OrangeStrykeLPAutomatorV2} from "./../../contracts/OrangeStrykeLPAutomatorV2.sol";

import {AutomatorV2Helper} from "../helper/AutomatorV2Helper.t.sol";

abstract contract OrangeStrykeLPAutomatorV2Harness is Test {
    OrangeStrykeLPAutomatorV2 public automator;

    constructor(OrangeStrykeLPAutomatorV2 automator_) {
        automator = automator_;
        automator.grantRole(automator.STRATEGIST_ROLE(), address(this));
    }

    function deposit(uint256 assets, address depositor) external {
        IERC20 _asset = automator.asset();
        deal(address(_asset), depositor, assets);
        vm.startPrank(depositor);
        _asset.approve(address(automator), assets);
        automator.deposit(assets);
        vm.stopPrank();
    }

    function rebalance(
        string memory ticksMint,
        string memory ticksBurn,
        address router,
        bytes memory swapCalldata,
        IOrangeStrykeLPAutomatorV2.RebalanceShortage memory shortage
    ) external {
        automator.setRouterWhitelist(router, true);

        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory mintTicks = AutomatorV2Helper.parseRebalanceTicksJson(
            ticksMint
        );
        IOrangeStrykeLPAutomatorV2.RebalanceTick[] memory burnTicks = AutomatorV2Helper.parseRebalanceTicksJson(
            ticksBurn
        );

        automator.rebalance(mintTicks, burnTicks, router, swapCalldata, shortage);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract WETH_USDC_OrangeStrykeLPAutomatorV2Harness is OrangeStrykeLPAutomatorV2Harness {
    constructor(
        uint256 initialDeposit,
        uint256 depositCap
    )
        OrangeStrykeLPAutomatorV2Harness(
            new OrangeStrykeLPAutomatorV2(
                OrangeStrykeLPAutomatorV2.InitArgs({
                    name: "WETH_USDC_OrangeStrykeLPAutomatorV2Harness",
                    symbol: "WETH_USDC",
                    admin: address(this),
                    manager: IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc),
                    handler: IUniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116),
                    handlerHook: address(0),
                    pool: IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
                    asset: IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
                    quoter: ChainlinkQuoter(0x42b404a21335449a524d701E51943d3e226Daa2A),
                    balancer: IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8),
                    assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                    counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                    minDepositAssets: 1000000000000000000
                })
            )
        )
    {
        automator.setDepositCap(depositCap);

        if (initialDeposit > 0) {
            deal(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, msg.sender, initialDeposit);
            vm.startPrank(msg.sender);
            IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(automator), initialDeposit);
            automator.deposit(initialDeposit);
            vm.stopPrank();
        }
    }
}
