// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase */

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ChainlinkQuoter} from "./../ChainlinkQuoter.sol";
import {IOrangeStrykeLPAutomatorState} from "./IOrangeStrykeLPAutomatorState.sol";

/**
 * @title IOrangeDopexV2LPAutomatorV1
 * @dev Interface for the Orange Dopex V2 LP Automator contract.
 * @author Orange Finance
 */
interface IOrangeStrykeLPAutomatorV1_1 is IOrangeStrykeLPAutomatorState {
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
     * @dev Returns the swap router contract.
     */
    function router() external view returns (ISwapRouter);

    /**
     * @dev Returns the Chainlink quoter contract.
     */
    function quoter() external view returns (ChainlinkQuoter);

    /**
     * @dev Returns the address of the asset USD feed.
     */
    function assetUsdFeed() external view returns (address);

    /**
     * @dev Returns the address of the counter asset USD feed.
     */
    function counterAssetUsdFeed() external view returns (address);

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
