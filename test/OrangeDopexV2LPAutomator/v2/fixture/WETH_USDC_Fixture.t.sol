// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase */

import {BaseFixture} from "./BaseFixture.t.sol";
import {IERC20} from "@openzeppelin/contracts//interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OrangeStrykeLPAutomatorV2Handler} from "../OrangeStrykeLPAutomatorV2Handler.t.sol";
import {IBalancerVault} from "./../../../../contracts/vendor/balancer/IBalancerVault.sol";

contract WETH_USDC_Fixture is BaseFixture {
    IERC20 public constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IUniswapV3Pool public pool = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);
    IBalancerVault public balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    OrangeStrykeLPAutomatorV2Handler public automator;

    function setUp() public virtual override {
        super.setUp();

        automator = new OrangeStrykeLPAutomatorV2Handler(
            OrangeStrykeLPAutomatorV2Handler.InitArgs({
                name: "OrangeStrykeLPAutomatorV2",
                symbol: "odpxWETH-USDC",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: chainlinkQuoter,
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                manager: manager,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: WETH,
                minDepositAssets: 0.01 ether,
                balancer: balancer,
                depositCap: 5000 ether,
                initialDeposit: 0
            })
        );
    }
}
