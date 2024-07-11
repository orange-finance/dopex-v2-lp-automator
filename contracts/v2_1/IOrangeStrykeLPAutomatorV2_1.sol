// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeSwapProxy} from "../swap-proxy/IOrangeSwapProxy.sol";
import {IUniswapV3PoolAdapter} from "../pool-adapter/IUniswapV3PoolAdapter.sol";
import {IOrangeQuoter} from "../interfaces/IOrangeQuoter.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/* solhint-disable contract-name-camelcase */

/**
 * @title IOrangeDopexV2LPAutomator
 * @dev Interface for the Orange Dopex V2 LP Automator contract.
 * @author Orange Finance
 */
interface IOrangeStrykeLPAutomatorV2_1 {
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
     * @dev Struct representing tick information for rebalancing.
     * @param tick The tick value.
     * @param liquidity The liquidity at the tick.
     */
    struct RebalanceTick {
        int24 tick;
        uint128 liquidity;
    }

    /**
     * @dev Struct representing user data for flash loans.
     * @param swapProxy The address of the OrangeSwapProxy contract.
     * @param swapRequest The swap detail sent to the OrangeSwapProxy contract.
     * @param mintCalldata The calldata for minting Stryke positions.
     * @param burnCalldata The calldata for burning Stryke positions.
     */
    struct FlashLoanUserData {
        address swapProxy;
        IOrangeSwapProxy.SwapInputRequest swapRequest;
        bytes[] mintCalldata;
        bytes[] burnCalldata;
    }

    event Deposit(address indexed sender, uint256 assets, uint256 sharesMinted);
    event Redeem(address indexed sender, uint256 shares, uint256 assetsWithdrawn);
    event Rebalance(address indexed sender, RebalanceTick[] ticksMint, RebalanceTick[] ticksBurn);

    event SetOwner(address indexed user, bool approved);
    event SetStrategist(address indexed user, bool approved);
    event SetDepositCap(uint256 depositCap);
    event SetDepositFeePips(uint24 depositFeePips);
    event SetProxyWhitelist(address indexed proxy, bool approved);
    event SetSwapInputDelta(uint256 swapInputDelta);

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
    error Unauthorized();
    error ProxyAlreadyWhitelisted();
    error FlashLoan_Unauthorized();

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
     * @dev Returns the amm pool contract.
     * @notice This function is used by merkl to get amm pool address
     */
    function pool() external view returns (address);

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

    /**
     * @dev Returns the pool adapter contract. it is used to normalize other pool (e.g. pancake) to the same interface as the Uniswap V3 pool.
     * @return poolAdapter The pool adapter contract.
     */
    function poolAdapter() external view returns (IUniswapV3PoolAdapter);

    /**
     * @dev Returns the minimum deposit of assets.
     */
    function minDepositAssets() external view returns (uint256);

    /**
     * @dev Returns the deposit cap.
     */
    function depositCap() external view returns (uint256);

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
     * @dev Rebalance the liquidity positions in the OrangeDopexV2LPAutomator contract.
     * Only the address with the STRATEGIST_ROLE can call this function.
     *
     * @param ticksMint An array of RebalanceTick structs representing the ticks to be minted.
     * @param ticksBurn An array of RebalanceTick structs representing the ticks to be burned.
     * @param swapProxy The address of the OrangeSwapProxy contract.
     * @param swapRequest The swap detail sent to the OrangeSwapProxy contract.
     * @param flashLoanData The flash loan data for the balancer v2.
     */
    function rebalance(
        RebalanceTick[] calldata ticksMint,
        RebalanceTick[] calldata ticksBurn,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest calldata swapRequest,
        bytes calldata flashLoanData
    ) external;
}
