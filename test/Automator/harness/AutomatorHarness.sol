// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {Automator, EnumerableSet, IDopexV2PositionManager, IUniswapV3SingleTickLiquidityHandler, ISwapRouter, IUniswapV3Pool, IERC20} from "../../../contracts/Automator.sol";

contract AutomatorHarness is Automator {
    constructor(
        address admin,
        IDopexV2PositionManager manager_,
        IUniswapV3SingleTickLiquidityHandler handler_,
        ISwapRouter router_,
        IUniswapV3Pool pool_,
        IERC20 asset_,
        uint256 minDepositAssets_
    ) Automator(admin, manager_, handler_, router_, pool_, asset_, minDepositAssets_) {}

    function pushActiveTick(int24 tick) external {
        EnumerableSet.add(activeTicks, uint256(uint24(tick)));
    }
}

function deployAutomatorHarness(
    address admin,
    address strategist,
    IDopexV2PositionManager manager_,
    IUniswapV3SingleTickLiquidityHandler handler_,
    ISwapRouter router_,
    IUniswapV3Pool pool_,
    IERC20 asset_,
    uint256 minDepositAssets_,
    uint256 depositCap
) returns (AutomatorHarness harness) {
    harness = new AutomatorHarness(admin, manager_, handler_, router_, pool_, asset_, minDepositAssets_);
    harness.grantRole(harness.STRATEGIST_ROLE(), strategist);
    harness.setDepositCap(depositCap);
}
