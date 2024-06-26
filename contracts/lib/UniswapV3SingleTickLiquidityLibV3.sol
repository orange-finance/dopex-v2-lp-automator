// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/**
 * @title UniswapV3SingleTickLiquidityLib
 * @dev Library for managing liquidity in a single Uniswap V3 tick.
 * @author Orange Finance
 */
library UniswapV3SingleTickLiquidityLibV3 {
    using TickMath for int24;

    struct PositionDetailParams {
        IUniswapV3SingleTickLiquidityHandlerV2 handler;
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        address owner;
    }

    /**
     * @dev Calculates the unique token ID for a given set of parameters.
     * @param handler The instance of the IUniswapV3SingleTickLiquidityHandlerV2 contract.
     * @param pool The address of the Uniswap V3 pool.
     * @param tickLower The lower tick of the range.
     * @param tickUpper The upper tick of the range.
     * @return The unique token ID.
     */
    function tokenId(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        address pool,
        address hook,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(handler, pool, hook, tickLower, tickUpper)));
    }

    /**
     * @dev Get the position detail of a given owner and token ID.
     * @dev option fee is already added in the liquidity via UniswapV3SingleTickLiquidityHandlerV2.donateToLiquidity function
     * @param params The parameters to request position detail.
     * @return all The total amount of liquidity the owner has.
     * @return redeemable The amount of liquidity that can be redeemed.
     * @return locked The amount of liquidity that is locked.
     * @return swapFee0 The amount of UniswapV3 Pool swap fee in token0.
     * @return swapFee1 The amount of UniswapV3 Pool swap fee in token1.
     * @notice swap fee (TokenIdInfo.tokenOwed0/1) is updated when the position is modified (mint/burn/use/unusePosition is called)
     * Automator modifies position when rebalance/redeem is called. Therefore, swap fee might be outdated in between these operations.
     */
    function positionDetail(
        PositionDetailParams memory params
    ) internal view returns (uint128 all, uint128 redeemable, uint128 locked, uint256 swapFee0, uint256 swapFee1) {
        uint256 _tokenId = tokenId(params.handler, params.pool, params.hook, params.tickLower, params.tickUpper);
        uint256 _shares = params.handler.balanceOf(params.owner, _tokenId);
        if (_shares == 0) return (0, 0, 0, 0, 0);

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tki = params.handler.tokenIds(_tokenId);

        all = params.handler.convertToAssets(uint128(_shares), _tokenId);

        // Starting from handler v2, totalLiquidity might be less than liquidityUsed because reservedLiquidity has been introduced.
        // Therefore, if totalLiquidity is less than liquidityUsed, we should return 0 to avoid underflow.
        uint128 freePool = _tki.totalLiquidity < _tki.liquidityUsed ? 0 : _tki.totalLiquidity - _tki.liquidityUsed;
        // If the vault is an only liquidity provider in the pool, 1 liquidity is locked in the pool.
        // because when first stryke mint, the liquidity calculation result is less by 1 than from second mint.
        // first mint does not use "convertToAssets" function, and not round up the result.
        if (all > _tki.totalLiquidity && freePool > 0) freePool -= 1;
        locked = all > freePool ? all - freePool : 0;

        redeemable = all - locked;

        // same fee calculation as Stryke handler:
        // https://github.com/stryke-xyz/dopex-v2-clamm/blob/0271d8c0ccd98e357935051de78d21343d11c811/src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol#L579

        (swapFee0, swapFee1) = _feesTokenOwed(
            params.tickLower,
            params.tickUpper,
            _tki.totalLiquidity,
            all,
            _tki.tokensOwed0,
            _tki.tokensOwed1
        );
    }

    function _feesTokenOwed(
        int24 tickLower,
        int24 tickUpper,
        uint128 totalLiquidity,
        uint128 userLiquidity,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) private pure returns (uint256 swapFee0, uint256 swapFee1) {
        uint256 totalLiquidity0 = LiquidityAmounts.getAmount0ForLiquidity(
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            totalLiquidity
        );

        uint256 totalLiquidity1 = LiquidityAmounts.getAmount1ForLiquidity(
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            totalLiquidity
        );

        uint256 userLiquidity0 = LiquidityAmounts.getAmount0ForLiquidity(
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            userLiquidity
        );

        uint256 userLiquidity1 = LiquidityAmounts.getAmount1ForLiquidity(
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            userLiquidity
        );

        if (totalLiquidity0 > 0) {
            swapFee0 = uint128((tokensOwed0 * userLiquidity0) / totalLiquidity0);
        }
        if (totalLiquidity1 > 0) {
            swapFee1 = uint128((tokensOwed1 * userLiquidity1) / totalLiquidity1);
        }
    }
}
