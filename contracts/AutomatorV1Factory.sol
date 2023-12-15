// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeVaultRegistry} from "./vendor/orange/IOrangeVaultRegistry.sol";
import {Automator, IDopexV2PositionManager, IUniswapV3SingleTickLiquidityHandler, ISwapRouter, IUniswapV3Pool, IERC20} from "./Automator.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract AutomatorV1Factory is AccessControlEnumerable {
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

    function createAutomator(InitArgs calldata initArgs) external onlyRole(DEFAULT_ADMIN_ROLE) returns (Automator) {
        return _create(initArgs);
    }

    function _create(InitArgs calldata initArgs) internal returns (Automator) {
        Automator automator = new Automator({
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
