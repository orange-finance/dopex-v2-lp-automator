// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase */

import {BaseFixture} from "./BaseFixture.t.sol";
import {IERC20} from "@openzeppelin/contracts//interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OrangeDopexV2LPAutomatorV1} from "../../../../contracts/OrangeDopexV2LPAutomatorV1.sol";
import {ChainlinkQuoter} from "./../../../../contracts/ChainlinkQuoter.sol";

contract WETH_USDC_Fixture is BaseFixture {
    IERC20 public constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IUniswapV3Pool public pool = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);

    OrangeDopexV2LPAutomatorV1 public automator;
    ChainlinkQuoter public chainlinkQuoter;

    function setUp() public virtual override {
        super.setUp();

        chainlinkQuoter = new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D));

        automator = new OrangeDopexV2LPAutomatorV1(
            OrangeDopexV2LPAutomatorV1.InitArgs({
                name: "OrangeDopexV2LPAutomatorV1",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: WETH,
                quoter: chainlinkQuoter,
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );

        automator.setDepositCap(5000 ether);

        automator.grantRole(automator.STRATEGIST_ROLE(), address(this));
        chainlinkQuoter.setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        chainlinkQuoter.setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
    }
}
