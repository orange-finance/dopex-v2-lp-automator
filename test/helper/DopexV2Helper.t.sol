// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

library DopexV2Helper {
    using TickMath for int24;

    IDopexV2PositionManager constant DOPEX_V2_POSITION_MANAGER =
        IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);

    address constant DOPEX_V2_MANAGER_OWNER = 0xEE82496D3ed1f5AFbEB9B29f3f59289fd899d9D0;

    IUniswapV3SingleTickLiquidityHandlerV2 constant DOPEX_UNIV3_HANDLER =
        IUniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116);

    function balanceOfHandler(
        address account,
        IUniswapV3Pool pool,
        address hook,
        int24 tickLower
    ) internal view returns (uint256) {
        return DOPEX_UNIV3_HANDLER.balanceOf(account, _tokenId(pool, hook, tickLower));
    }

    function useDopexPosition(IUniswapV3Pool pool, address hook, int24 tickLower, uint128 liquidityToUse) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.UsePositionParams memory _params = IUniswapV3SingleTickLiquidityHandlerV2
            .UsePositionParams({
                pool: address(pool),
                hook: hook,
                tickLower: tickLower,
                tickUpper: tickLower + pool.tickSpacing(),
                liquidityToUse: liquidityToUse
            });

        DOPEX_V2_POSITION_MANAGER.usePosition(DOPEX_UNIV3_HANDLER, abi.encode(_params, ""));
    }

    function dopexLiquidityOf(
        IUniswapV3Pool pool,
        address hook,
        address account,
        int24 tickLower
    ) internal view returns (uint128) {
        return _dopexLiquidityOf(pool, hook, account, tickLower);
    }

    function totalLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) internal view returns (uint128) {
        return _totalLiquidityOfTick(pool, hook, tickLower);
    }

    function usedLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) internal view returns (uint128) {
        return _usedLiquidityOfTick(pool, hook, tickLower);
    }

    function freeLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) internal view returns (uint128) {
        return _freeLiquidityOfTick(pool, hook, tickLower);
    }

    function freeLiquidityOfTickByOthers(
        IUniswapV3Pool pool,
        address hook,
        address account,
        int24 tickLower
    ) internal view returns (uint128) {
        uint128 _free = _freeLiquidityOfTick(pool, hook, tickLower);
        uint128 _myLiq = _dopexLiquidityOf(pool, hook, account, tickLower);

        if (_myLiq > _free) return 0;

        return _free - _myLiq;
    }

    function _dopexLiquidityOf(
        IUniswapV3Pool pool,
        address hook,
        address account,
        int24 tickLower
    ) private view returns (uint128) {
        uint256 _shares = DOPEX_UNIV3_HANDLER.balanceOf(account, _tokenId(pool, hook, tickLower));
        if (_shares == 0) return 0;

        return DOPEX_UNIV3_HANDLER.convertToAssets(uint128(_shares), _tokenId(pool, hook, tickLower));
    }

    function _totalLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) private view returns (uint128) {
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _ti = _tokenIdInfo(pool, hook, tickLower);

        return _ti.totalLiquidity;
    }

    function _usedLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) private view returns (uint128) {
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _ti = _tokenIdInfo(pool, hook, tickLower);

        return _ti.liquidityUsed;
    }

    function _freeLiquidityOfTick(IUniswapV3Pool pool, address hook, int24 tickLower) private view returns (uint128) {
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _ti = _tokenIdInfo(pool, hook, tickLower);

        return _ti.totalLiquidity - _ti.liquidityUsed;
    }

    function tokenIdInfo(
        IUniswapV3Pool pool,
        address hook,
        int24 tickLower
    ) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory) {
        return _tokenIdInfo(pool, hook, tickLower);
    }

    function _tokenIdInfo(
        IUniswapV3Pool pool,
        address hook,
        int24 tickLower
    ) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory) {
        return DOPEX_UNIV3_HANDLER.tokenIds(_tokenId(pool, hook, tickLower));
    }

    function _tokenId(IUniswapV3Pool pool, address hook, int24 tickLower) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encode(DOPEX_UNIV3_HANDLER, pool, hook, tickLower, tickLower + pool.tickSpacing())));
    }
}
