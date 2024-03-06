// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase , var-name-mixedcase, state-visibility, contract-name-camelcase */
import {OrangeDopexV2LPAutomatorV1} from "../../../contracts/OrangeDopexV2LPAutomatorV1.sol";
import {ChainlinkQuoter} from "../../../contracts/ChainlinkQuoter.sol";

import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";

contract TestOrangeStrykeLPAutomatorV1_1Deploy is WETH_USDC_Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();
    }

    function test_deploy_revertUnsupportedAssetsDecimals() public {
        vm.mockCall(address(WETH), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomatorV1.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomatorV1(
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
                quoter: ChainlinkQuoter(address(1)),
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );
    }

    function test_deploy_revertUnsupportedCounterAssetsDecimals() public {
        vm.mockCall(address(USDC), abi.encodeWithSignature("decimals()"), abi.encode(uint8(2)));

        vm.expectRevert(OrangeDopexV2LPAutomatorV1.UnsupportedDecimals.selector);
        new OrangeDopexV2LPAutomatorV1(
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
                quoter: ChainlinkQuoter(address(1)),
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );
    }
}
