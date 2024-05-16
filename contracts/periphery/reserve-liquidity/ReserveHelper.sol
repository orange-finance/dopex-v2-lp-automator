// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IReserveHelper} from "./IReserveHelper.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "./../../lib/UniswapV3SingleTickLiquidityLibV2.sol";

contract ReserveHelper is IReserveHelper {
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using EnumerableSet for EnumerableSet.UintSet;

    struct BatchWithdrawCache {
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams request;
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams position;
        uint256 tokenId;
        uint256 prev0;
        uint256 prev1;
    }

    mapping(address user => mapping(uint256 tokenId => IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams position))
        public userReservedPositions;
    mapping(address user => EnumerableSet.UintSet tokenIds) internal _userReservedTokenIds;

    address public user;
    address public proxy;

    event ReserveLiquidity(
        address indexed user,
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams reservedPosition
    );
    event WithdrawReservedLiquidity(
        address indexed user,
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams reservedPosition
    );

    error OnlyProxy();

    modifier onlyProxy() {
        if (msg.sender != proxy) revert OnlyProxy();
        _;
    }

    constructor(address user_) {
        user = user_;
        proxy = msg.sender;
    }

    function getReservedPositions()
        external
        view
        returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory positions)
    {
        address _user = user;
        positions = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](
            _userReservedTokenIds[_user].length()
        );

        for (uint256 i; i < positions.length; ) {
            positions[i] = userReservedPositions[_user][_userReservedTokenIds[_user].at(i)];
            unchecked {
                i++;
            }
        }
    }

    function batchReserveLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] calldata reserveLiquidityParams
    )
        external
        onlyProxy
        returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reservedPositions)
    {
        uint256 len = reserveLiquidityParams.length;

        for (uint256 i; i < len; ) {
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory request = reserveLiquidityParams[i];
            uint256 tokenId = handler.tokenId(request.pool, request.hook, request.tickLower, request.tickUpper);

            handler.transferFrom(user, address(this), tokenId, request.shares);

            // this is update active list if not exist
            _userReservedTokenIds[user].add(tokenId);

            // cache current position to save gas
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory position = userReservedPositions[user][
                tokenId
            ];
            uint128 prevShares = position.shares;
            // override with requested position, and add previous shares if exists
            position = request;
            position.shares += prevShares;

            // update storage
            userReservedPositions[user][tokenId] = position;

            // execute reserve liquidity
            handler.reserveLiquidity(abi.encode(request));

            emit ReserveLiquidity(user, handler, request);

            unchecked {
                i++;
            }
        }

        return reserveLiquidityParams;
    }

    function batchWithdrawReservedLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] calldata reservePositions
    ) external onlyProxy {
        address _user = user;
        uint256 len = reservePositions.length;

        BatchWithdrawCache memory cache;

        uint256 withdrawable;

        for (uint256 i; i < len; ) {
            cache.request = reservePositions[i];

            // condition has not met, skip
            withdrawable = _withdrawableLiquidity(handler, cache.request);
            if (withdrawable == 0) {
                unchecked {
                    i++;
                }
                continue;
            }

            cache.tokenId = handler.tokenId(
                cache.request.pool,
                cache.request.hook,
                cache.request.tickLower,
                cache.request.tickUpper
            );

            cache.position = userReservedPositions[_user][cache.tokenId];
            cache.position.shares -= cache.request.shares;
            // if all shares are withdrawn, remove from active list
            if (cache.position.shares == 0) _userReservedTokenIds[_user].remove(cache.tokenId);

            // update storage
            userReservedPositions[_user][cache.tokenId] = cache.position;

            IERC20 token0 = IERC20(IUniswapV3Pool(cache.request.pool).token0());
            IERC20 token1 = IERC20(IUniswapV3Pool(cache.request.pool).token1());

            uint256 prev0 = token0.balanceOf(address(this));
            uint256 prev1 = token1.balanceOf(address(this));

            handler.withdrawReserveLiquidity(abi.encode(cache.request));

            // transfer dissolved position to user
            uint256 diff0 = token0.balanceOf(address(this)) - prev0;
            uint256 diff1 = token1.balanceOf(address(this)) - prev1;

            if (diff0 > 0) token0.transfer(_user, diff0);
            if (diff1 > 0) token1.transfer(_user, diff1);

            emit WithdrawReservedLiquidity(user, handler, cache.request);

            unchecked {
                i++;
            }
        }
    }

    function _withdrawableLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory reservePosition
    ) internal returns (uint256 withdrawable) {
        IUniswapV3SingleTickLiquidityHandlerV2.ReserveLiquidityData memory rld = handler.reservedLiquidityPerUser(
            handler.tokenId(
                reservePosition.pool,
                reservePosition.hook,
                reservePosition.tickLower,
                reservePosition.tickUpper
            ),
            address(this)
        );

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory tki = handler.tokenIds(
            handler.tokenId(
                reservePosition.pool,
                reservePosition.hook,
                reservePosition.tickLower,
                reservePosition.tickUpper
            )
        );

        // if reserve cooldown has not passed. no withdrawable liquidity exists
        if (rld.lastReserve + handler.reserveCooldown() > block.timestamp) return 0;

        // if free liquidity of handler is not enough, return only available liquidity
        uint256 free = tki.totalLiquidity + tki.reservedLiquidity - tki.liquidityUsed;
        if (free < reservePosition.shares) return free;

        return reservePosition.shares;
    }
}
