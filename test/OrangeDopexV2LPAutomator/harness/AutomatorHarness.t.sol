// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {OrangeDopexV2LPAutomator, EnumerableSet, IDopexV2PositionManager, IUniswapV3SingleTickLiquidityHandler, ISwapRouter, IUniswapV3Pool, IERC20} from "../../../contracts/OrangeDopexV2LPAutomator.sol";

contract AutomatorHarness is OrangeDopexV2LPAutomator {
    constructor(
        string memory name,
        string memory symbol,
        address admin,
        IDopexV2PositionManager manager_,
        IUniswapV3SingleTickLiquidityHandler handler_,
        ISwapRouter router_,
        IUniswapV3Pool pool_,
        IERC20 asset_,
        uint256 minDepositAssets_
    ) OrangeDopexV2LPAutomator(name, symbol, admin, manager_, handler_, router_, pool_, asset_, minDepositAssets_) {}

    function pushActiveTick(int24 tick) external {
        EnumerableSet.add(activeTicks, uint256(uint24(tick)));
    }
}

function deployAutomatorHarness(
    string memory name,
    string memory symbol,
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
    harness = new AutomatorHarness(name, symbol, admin, manager_, handler_, router_, pool_, asset_, minDepositAssets_);
    harness.grantRole(harness.STRATEGIST_ROLE(), strategist);
    harness.setDepositCap(depositCap);
}
