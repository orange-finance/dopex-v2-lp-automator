// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";

/**
 * @title IOrangeDopexV2LPAutomatorV1
 * @dev Interface for the Orange Dopex V2 LP Automator contract.
 * @author Orange Finance
 */
interface IOrangeStrykeLPAutomatorV1_1 {
    /**
     * @dev Struct representing locked Dopex shares.
     * @param tokenId The ID of the token.
     * @param shares The number of shares locked.
     */
    struct LockedDopexShares {
        uint256 tokenId;
        uint256 shares;
    }

    /**
     * @dev Struct representing parameters for rebalancing swaps.
     * @param assetsShortage The shortage of assets.
     * @param counterAssetsShortage The shortage of counter assets.
     * @param maxCounterAssetsUseForSwap The maximum amount of counter assets to use for swapping.
     * @param maxAssetsUseForSwap The maximum amount of assets to use for swapping.
     */
    struct RebalanceSwapParams {
        uint256 assetsShortage;
        uint256 counterAssetsShortage;
        uint256 maxCounterAssetsUseForSwap;
        uint256 maxAssetsUseForSwap;
    }

    /**
     * @dev Struct representing tick information for rebalancing.
     * @param tick The tick value.
     * @param liquidity The liquidity at the tick.
     */
    struct RebalanceTickInfo {
        int24 tick;
        uint128 liquidity;
    }

    event Deposit(address indexed sender, uint256 assets, uint256 sharesMinted);
    event Redeem(address indexed sender, uint256 shares, uint256 assetsWithdrawn);
    event Rebalance(address indexed sender, RebalanceTickInfo[] ticksMint, RebalanceTickInfo[] ticksBurn);

    event SetOwner(address user, bool approved);
    event SetStrategist(address user, bool approved);
    event DepositCapSet(uint256 depositCap);
    event DepositFeePipsSet(uint24 depositFeePips);

    error AddressZero();
    error AmountZero();
    error MaxTicksReached();
    error InvalidRebalanceParams();
    error MinAssetsRequired(uint256 minAssets, uint256 actualAssets);
    error TokenAddressMismatch();
    error TokenNotPermitted();
    error DepositTooSmall();
    error DepositCapExceeded();
    error SharesTooSmall();
    error FeePipsTooHigh();
    error UnsupportedDecimals();
    error MinDepositAssetsTooSmall();
    error OnlyOwner();

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
     * @dev Returns the swap router contract.
     */
    function router() external view returns (ISwapRouter);

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
     * @dev Returns the minimum deposit of assets.
     */
    function minDepositAssets() external view returns (uint256);

    /**
     * @dev Returns the deposit cap.
     */
    function depositCap() external view returns (uint256);

    /**
     * @dev Retrieves the active ticks as an array of int24 values.
     * @return An array of int24 values representing the active ticks.
     */
    function getActiveTicks() external view returns (int24[] memory);

    /**
     * @dev Retrieves the positions of the automator.
     * @return balanceDepositAsset The balance of the deposit asset.
     * @return balanceCounterAsset The balance of the counter asset.
     * @return ticks An array of structs representing the active ticks and its liquidity.
     */
    function getAutomatorPositions()
        external
        view
        returns (uint256 balanceDepositAsset, uint256 balanceCounterAsset, RebalanceTickInfo[] memory ticks);

    /**
     * @dev Calculates the total assets in the automator contract.
     * It includes the assets in the Dopex pools and the automator contract itself.
     * @return The total assets in the automator contract.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev Calculates the total free assets in Dopex pools and returns the sum.
     * Free assets are the assets that can be redeemed from the pools.
     * This function iterates through the active ticks in the pool and calculates the liquidity
     * that can be redeemed for each tick. It then converts the liquidity to token amounts using
     * the current sqrt ratio and tick values. The sum of token amounts is calculated and merged
     * with the total assets in the automator. Finally, the quote value is obtained using the
     * current tick and the base value, and returned as the result.
     * @return The total free assets in Dopex pools.
     */
    function freeAssets() external view returns (uint256);

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

    /**
     * @dev Retrieves the total liquidity of a given tick range.
     * @param tick The tick value representing the range.
     * @return The total liquidity of the tick range.
     */
    function getTickAllLiquidity(int24 tick) external view returns (uint128);

    /**
     * @dev Retrieves the amount of free liquidity for a given tick.
     * @param tick The tick value for which to retrieve the free liquidity.
     * @return The amount of free liquidity for the specified tick.
     */
    function getTickFreeLiquidity(int24 tick) external view returns (uint128);

    /**
     * @dev Deposits the specified amount of assets into the contract and returns the corresponding number of shares.
     * @param assets The amount of assets to deposit.
     * @return shares The number of shares received after the deposit.
     * @notice This function allows users to deposit assets into the contract.
     * It performs various checks such as ensuring the amount is not zero, not below the minimum deposit assets, and not exceeding the deposit cap.
     * If the total supply of shares is zero, a small portion is minted to the zero address, and the remaining shares are assigned to the depositor.
     * If there is a performance fee, it is deducted from the shares and minted to the performance fee recipient.
     * Finally, the shares are minted to the depositor's address and the assets are transferred from the depositor to the contract.
     */
    function deposit(uint256 assets) external returns (uint256 shares);

    /**
     * @dev Redeems a specified number of shares and returns the redeemed assets along with the locked Dopex shares.
     * @param shares The number of shares to redeem.
     * @param minAssets The minimum required assets to be redeemed.
     * @return assets The redeemed assets.
     * @return lockedDopexShares An array of locked Dopex shares.
     */
    function redeem(
        uint256 shares,
        uint256 minAssets
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares);

    /**
     * @dev Rebalance the liquidity positions in the OrangeDopexV2LPAutomatorV1 contract.
     * Only the address with the STRATEGIST_ROLE can call this function.
     *
     * @param ticksMint An array of RebalanceTickInfo structs representing the ticks to be minted.
     * @param ticksBurn An array of RebalanceTickInfo structs representing the ticks to be burned.
     * @param swapParams A RebalanceSwapParams struct representing the swap parameters for rebalancing.
     */
    function rebalance(
        RebalanceTickInfo[] calldata ticksMint,
        RebalanceTickInfo[] calldata ticksBurn,
        RebalanceSwapParams calldata swapParams
    ) external;
}
