// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeVaultRegistry} from "./vendor/orange/IOrangeVaultRegistry.sol";
import {OrangeDopexV2LPAutomator, IDopexV2PositionManager, IUniswapV3SingleTickLiquidityHandler, ISwapRouter, IUniswapV3Pool, IERC20} from "./OrangeDopexV2LPAutomator.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract OrangeDopexV2LPAutomatorV1Factory is AccessControlEnumerable {
    IOrangeVaultRegistry public immutable registry;

    constructor(IOrangeVaultRegistry _registry) {
        registry = _registry;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    struct InitArgs {
        address admin;
        IDopexV2PositionManager manager;
        IUniswapV3SingleTickLiquidityHandler handler;
        ISwapRouter router;
        IUniswapV3Pool pool;
        IERC20 asset;
        uint256 minDepositAssets;
    }

    function createOrangeDopexV2LPAutomator(
        InitArgs calldata initArgs
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (OrangeDopexV2LPAutomator) {
        return _create(initArgs);
    }

    function _create(InitArgs calldata initArgs) internal returns (OrangeDopexV2LPAutomator) {
        OrangeDopexV2LPAutomator automator = new OrangeDopexV2LPAutomator({
            admin: initArgs.admin,
            manager_: initArgs.manager,
            handler_: initArgs.handler,
            router_: initArgs.router,
            pool_: initArgs.pool,
            asset_: initArgs.asset,
            minDepositAssets_: initArgs.minDepositAssets
        });

        registry.add({
            vault: address(automator),
            version: "V1_DOPEX_AUTOMATOR",
            // NOTE: parameter is stored in an automator itself
            parameters: address(automator)
        });

        return automator;
    }
}
