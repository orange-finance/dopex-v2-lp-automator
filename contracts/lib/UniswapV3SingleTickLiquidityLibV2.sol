// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

/**
 * @title UniswapV3SingleTickLiquidityLib
 * @dev Library for managing liquidity in a single Uniswap V3 tick.
 * @author Orange Finance
 */
library UniswapV3SingleTickLiquidityLibV2 {
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

    function positionDetail(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        address owner,
        uint256 tokenId_
    ) internal view returns (uint128 all, uint128 redeemable, uint128 locked) {
        uint256 _shares = handler.balanceOf(owner, tokenId_);
        if (_shares == 0) return (0, 0, 0);

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tki = handler.tokenIds(tokenId_);

        all = handler.convertToAssets(uint128(_shares), tokenId_);

        // Starting from handler v2, totalLiquidity might be less than liquidityUsed because reservedLiquidity has been introduced.
        // Therefore, if totalLiquidity is less than liquidityUsed, we should return 0 to avoid underflow.
        uint128 freePool = _tki.totalLiquidity < _tki.liquidityUsed ? 0 : _tki.totalLiquidity - _tki.liquidityUsed;
        // If the vault is an only liquidity provider in the pool, 1 liquidity is locked in the pool.
        // because when first stryke mint, the liquidity calculation result is less by 1 than from second mint.
        // first mint does not use "convertToAssets" function, and not round up the result.
        if (all > _tki.totalLiquidity && freePool > 0) freePool -= 1;
        locked = all > freePool ? all - freePool : 0;

        redeemable = all - locked;
    }
}
