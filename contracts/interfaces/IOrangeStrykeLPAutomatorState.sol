// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase */

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";

import {IOrangeQuoter} from "./IOrangeQuoter.sol";

/**
 * @title IOrangeStrykeLPAutomatorState
 * @dev Interface for the Orange Stryke LP Automator state.
 * @author Orange Finance
 */
interface IOrangeStrykeLPAutomatorState {
    /**
     * @dev Struct representing tick information for rebalancing.
     * @param tick The tick value.
     * @param liquidity The liquidity at the tick.
     */
    struct RebalanceTickInfo {
        int24 tick;
        uint128 liquidity;
    }

    /**
     * @dev Returns the position manager contract.
     */
    function manager() external view returns (IDopexV2PositionManager);

    /**
     * @dev Returns the liquidity handler contract.
     */
    function handler() external view returns (IUniswapV3SingleTickLiquidityHandlerV2);

    /**
     * @dev Returns the handler hook contract.
     */
    function handlerHook() external view returns (address);

    /**
     * @dev Returns the Uniswap V3 pool contract.
     */
    function pool() external view returns (IUniswapV3Pool);

    /**
     * @dev Returns the Chainlink quoter contract.
     */
    function quoter() external view returns (IOrangeQuoter);

    /**
     * @dev Returns the address of the asset USD feed.
     */
    function assetUsdFeed() external view returns (address);

    /**
     * @dev Returns the address of the counter asset USD feed.
     */
    function counterAssetUsdFeed() external view returns (address);

    /**
     * @dev Returns the deposit asset token contract.
     */
    function asset() external view returns (IERC20);

    /**
     * @dev Returns the counter asset token contract.
     */
    function counterAsset() external view returns (IERC20);

    /**
     * @dev Returns the tick spacing of the pool.
     */
    function poolTickSpacing() external view returns (int24);

    /**
     * @dev Retrieves the active ticks as an array of int24 values.
     * @return An array of int24 values representing the active ticks.
     */
    function getActiveTicks() external view returns (int24[] memory);

    /**
     * @dev Calculates the total assets in the automator contract.
     * It includes the assets in the Dopex pools and the automator contract itself.
     * @return The total assets in the automator contract.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev Converts the given amount of assets to shares based on the total supply and total assets.
     * @param assets The amount of assets to convert to shares.
     * @return The converted amount of shares.
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @dev Converts the given amount of shares to assets based on the total supply and total assets.
     * @param shares The amount of shares to convert to assets.
     * @return The converted amount of assets.
     */
    function convertToAssets(uint256 shares) external view returns (uint256);
}
