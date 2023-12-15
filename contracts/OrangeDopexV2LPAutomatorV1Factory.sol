// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeVaultRegistry} from "./vendor/orange/IOrangeVaultRegistry.sol";
import {OrangeDopexV2LPAutomator, IDopexV2PositionManager, IUniswapV3SingleTickLiquidityHandler, ISwapRouter, IUniswapV3Pool, IERC20} from "./OrangeDopexV2LPAutomator.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import {IERC20Symbol} from "./interfaces/IERC20Extended.sol";

/**
 * @title OrangeDopexV2LPAutomatorV1Factory
 * @dev This contract is the factory contract for creating instances of OrangeDopexV2LPAutomator
 * @author Orange Finance
 */
contract OrangeDopexV2LPAutomatorV1Factory is AccessControlEnumerable {
    IOrangeVaultRegistry public immutable registry;

    /**
     * @dev Constructor function for the OrangeDopexV2LPAutomatorV1Factory contract.
     * @param _registry The address of the OrangeVaultRegistry contract.
     */
    constructor(IOrangeVaultRegistry _registry) {
        registry = _registry;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Struct representing the initialization arguments for the OrangeDopexV2LPAutomatorV1Factory contract.
     */
    struct InitArgs {
        address admin; // The address of the admin
        IDopexV2PositionManager manager; // The instance of the DopexV2PositionManager contract
        IUniswapV3SingleTickLiquidityHandler handler; // The instance of the UniswapV3SingleTickLiquidityHandler contract
        ISwapRouter router; // The instance of the SwapRouter contract
        IUniswapV3Pool pool; // The instance of the UniswapV3Pool contract
        IERC20 asset; // The instance of the ERC20 asset contract
        uint256 minDepositAssets; // The minimum amount of assets required for deposit
    }

    /**
     * @dev Creates a new instance of the OrangeDopexV2LPAutomator contract.
     *
     * This function can only be called by the account with the DEFAULT_ADMIN_ROLE.
     *
     * @param initArgs The initialization arguments for the OrangeDopexV2LPAutomator contract.
     * @return The newly created OrangeDopexV2LPAutomator contract instance.
     */
    function createOrangeDopexV2LPAutomator(
        InitArgs calldata initArgs
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (OrangeDopexV2LPAutomator) {
        return _create(initArgs);
    }

    function _create(InitArgs calldata initArgs) internal returns (OrangeDopexV2LPAutomator) {
        // NOTE: Concatenates the token name using the symbols of token0 and token1.
        string memory _tokenName = string.concat(
            "odpx",
            IERC20Symbol(initArgs.pool.token0()).symbol(),
            "-",
            IERC20Symbol(initArgs.pool.token1()).symbol()
        );

        OrangeDopexV2LPAutomator automator = new OrangeDopexV2LPAutomator({
            name: _tokenName,
            symbol: _tokenName,
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
