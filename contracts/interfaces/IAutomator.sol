// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LiquidityAmounts} from "../vendor/uniswapV3/LiquidityAmounts.sol";
import {TickMath} from "../vendor/uniswapV3/TickMath.sol";
import {OracleLibrary} from "../vendor/uniswapV3/OracleLibrary.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IUniswapV3SingleTickLiquidityHandler} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {UniswapV3SingleTickLiquidityLib} from "../lib/UniswapV3SingleTickLiquidityLib.sol";
import {UniswapV3PoolLib} from "../lib/UniswapV3PoolLib.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";

interface IAutomator {
    function manager() external view returns (IDopexV2PositionManager);

    function handler() external view returns (IUniswapV3SingleTickLiquidityHandler);

    function pool() external view returns (IUniswapV3Pool);

    function router() external view returns (ISwapRouter);

    function asset() external view returns (IERC20);

    function counterAsset() external view returns (IERC20);

    function poolTickSpacing() external view returns (int24);

    function minDepositAssets() external view returns (uint256);

    function depositCap() external view returns (uint256);

    function getActiveTicks() external view returns (uint256[] memory);

    // Structs
    struct LockedDopexShares {
        uint256 tokenId;
        uint256 shares;
    }

    struct RebalanceSwapParams {
        uint256 assetsShortage;
        uint256 counterAssetsShortage;
        uint256 maxCounterAssetsUseForSwap;
        uint256 maxAssetsUseForSwap;
    }

    struct RebalanceTickInfo {
        int24 tick;
        uint128 liquidity;
    }

    // Functions
    function setDepositCap(uint256 _depositCap) external;

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function getTickAllLiquidity(int24 tick) external view returns (uint128);

    function getTickFreeLiquidity(int24 tick) external view returns (uint128);

    function calculateRebalanceSwapParamsInRebalance(
        UniswapV3PoolLib.Position[] calldata mintPositions,
        UniswapV3PoolLib.Position[] calldata burnPositions
    ) external view returns (RebalanceSwapParams memory);

    function deposit(uint256 assets) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        uint256 minAssets
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares);

    function checkMintValidity(int24 lowerTick, int24 upperTick) external view returns (bool);

    function rebalance(
        RebalanceMintParams[] calldata mintParams,
        RebalanceBurnParams[] calldata burnParams,
        RebalanceSwapParams calldata swapParams
    ) external;

    // Add any other public or external functions from the Automator contract here
}
