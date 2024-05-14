// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IReserveHelper} from "./interfaces/IReserveHelper.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "./../lib/UniswapV3SingleTickLiquidityLibV2.sol";

contract ReserveHelper is IReserveHelper {
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address user => mapping(uint256 tokenId => IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams position))
        public userReservedPositions;
    mapping(address user => EnumerableSet.UintSet tokenIds) internal _userReservedTokenIds;

    function getReservedPositions(
        address user
    ) external view returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory positions) {
        positions = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](
            _userReservedTokenIds[user].length()
        );

        for (uint256 i = 0; i < positions.length; ) {
            positions[i] = userReservedPositions[user][_userReservedTokenIds[user].at(i)];
            unchecked {
                i++;
            }
        }
    }

    function batchReserveLiquidity(
        address user,
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] calldata reserveLiquidityParams
    ) external returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reservedPositions) {
        uint256 len = reserveLiquidityParams.length;

        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory position;
        uint256 tokenId;

        for (uint256 i = 0; i < len; ) {
            position = reserveLiquidityParams[i];
            tokenId = handler.tokenId(position.pool, position.hook, position.tickLower, position.tickUpper);

            handler.transferFrom(user, address(this), tokenId, position.shares);

            _userReservedTokenIds[user].add(tokenId);
            userReservedPositions[user][tokenId].shares += position.shares;

            unchecked {
                handler.reserveLiquidity(abi.encode(position));
                i++;
            }
        }

        emit BatchReserveLiquidity(user, handler, reserveLiquidityParams);

        return reserveLiquidityParams;
    }

    function batchWithdrawReservedPositions(
        address user,
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] calldata reservePositions
    ) external {
        uint256 len = reservePositions.length;

        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory position;
        uint256 tokenId;

        for (uint256 i = 0; i < len; ) {
            position = reservePositions[i];
            tokenId = handler.tokenId(position.pool, position.hook, position.tickLower, position.tickUpper);

            userReservedPositions[user][tokenId].shares -= position.shares;

            handler.withdrawReserveLiquidity(abi.encode(position));

            unchecked {
                i++;
            }
        }
    }
}
