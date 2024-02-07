// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title UniswapV3SingleTickLiquidityLib
 * @dev Library for managing liquidity in a single Uniswap V3 tick.
 * @author Orange Finance
 */
library UniswapV3SingleTickLiquidityLib {
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
     * @dev Calculates the redeemable liquidity for a given owner and token ID.
     * @param handler The instance of the UniswapV3SingleTickLiquidityHandler contract.
     * @param owner The address of the owner.
     * @param tokenId_ The ID of the token.
     * @return liquidity The amount of redeemable liquidity.
     */
    function redeemableLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        address owner,
        uint256 tokenId_
    ) internal view returns (uint256 liquidity) {
        uint256 _shares = handler.balanceOf(owner, tokenId_);
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tki = handler.tokenIds(tokenId_);

        // NOTE: The amount of redeemable liquidity is the minimum of the amount of own shares and the amount of free liquidity.
        liquidity = Math.min(
            handler.convertToAssets(uint128(_shares), tokenId_),
            _tki.totalLiquidity - _tki.liquidityUsed
        );
    }

    /**
     * @dev Calculates the amount of locked liquidity for a given owner and token ID.
     * @param handler The instance of the IUniswapV3SingleTickLiquidityHandlerV2 contract.
     * @param owner The address of the liquidity owner.
     * @param tokenId_ The ID of the liquidity token.
     * @return The amount of locked liquidity.
     */
    function lockedLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        address owner,
        uint256 tokenId_
    ) internal view returns (uint256) {
        uint256 _shares = handler.balanceOf(owner, tokenId_);
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tki = handler.tokenIds(tokenId_);

        uint256 _maxRedeem = handler.convertToAssets(uint128(_shares), tokenId_);
        uint256 _freeLiquidity = _tki.totalLiquidity - _tki.liquidityUsed;

        if (_freeLiquidity >= _maxRedeem) return 0;

        return _maxRedeem - _freeLiquidity;
    }
}
