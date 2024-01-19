// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {OrangeDopexV2LPAutomator, EnumerableSet} from "../../../contracts/OrangeDopexV2LPAutomator.sol";

contract AutomatorHarness is OrangeDopexV2LPAutomator {
    constructor(
        InitArgs memory args
    )
        OrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomator.InitArgs({
                name: args.name,
                symbol: args.symbol,
                admin: args.admin,
                assetUsdFeed: args.assetUsdFeed,
                counterAssetUsdFeed: args.counterAssetUsdFeed,
                quoter: args.quoter,
                manager: args.manager,
                handler: args.handler,
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
    OrangeDopexV2LPAutomator.InitArgs memory args,
    address strategist,
    uint256 depositCap
) returns (AutomatorHarness harness) {
    harness = new AutomatorHarness(args);
    harness.grantRole(harness.STRATEGIST_ROLE(), strategist);
    harness.setDepositCap(depositCap);
}
