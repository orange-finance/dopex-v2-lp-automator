// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOrangeStrykeLPAutomatorState} from "./../interfaces/IOrangeStrykeLPAutomatorState.sol";
import {IOrangeSwapProxy} from "./IOrangeSwapProxy.sol";

/**
 * @title IOrangeDopexV2LPAutomator
 * @dev Interface for the Orange Dopex V2 LP Automator contract.
 * @author Orange Finance
 */
interface IOrangeStrykeLPAutomatorV2 is IOrangeStrykeLPAutomatorState {
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

    struct FlashLoanUserData {
        address swapProxy;
        IOrangeSwapProxy.SwapInputRequest swapRequest;
        bytes[] mintCalldata;
        bytes[] burnCalldata;
    }

    event Deposit(address indexed sender, uint256 assets, uint256 sharesMinted);
    event Redeem(address indexed sender, uint256 shares, uint256 assetsWithdrawn);
    event Rebalance(address indexed sender, RebalanceTick[] ticksMint, RebalanceTick[] ticksBurn);

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
    error Unauthorized();
    error ProxyAlreadyWhitelisted();
    error FlashLoan_Unauthorized();

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
     * @param redeemData Additional data for the redemption.
     * @return assets The redeemed assets.
     * @return lockedDopexShares An array of locked Dopex shares.
     */
    function redeem(
        uint256 shares,
        bytes calldata redeemData
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
