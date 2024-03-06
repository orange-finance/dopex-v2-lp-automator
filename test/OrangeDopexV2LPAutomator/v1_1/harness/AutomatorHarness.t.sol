// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {OrangeDopexV2LPAutomatorV1, EnumerableSet} from "../../../../contracts/OrangeDopexV2LPAutomatorV1.sol";

contract AutomatorHarness is OrangeDopexV2LPAutomatorV1 {
    constructor(
        InitArgs memory args
    )
        OrangeDopexV2LPAutomatorV1(
            OrangeDopexV2LPAutomatorV1.InitArgs({
                name: args.name,
                symbol: args.symbol,
                admin: args.admin,
                assetUsdFeed: args.assetUsdFeed,
                counterAssetUsdFeed: args.counterAssetUsdFeed,
                quoter: args.quoter,
                manager: args.manager,
                handler: args.handler,
                handlerHook: args.handlerHook,
                router: args.router,
                pool: args.pool,
                asset: args.asset,
                minDepositAssets: args.minDepositAssets
            })
        )
    {}

    function pushActiveTick(int24 tick) external {
        EnumerableSet.add(activeTicks, uint256(uint24(tick)));
    }
}

function deployAutomatorHarness(
    OrangeDopexV2LPAutomatorV1.InitArgs memory args,
    address strategist,
    uint256 depositCap
) returns (AutomatorHarness harness) {
    harness = new AutomatorHarness(args);
    harness.grantRole(harness.STRATEGIST_ROLE(), strategist);
    harness.setDepositCap(depositCap);
}
