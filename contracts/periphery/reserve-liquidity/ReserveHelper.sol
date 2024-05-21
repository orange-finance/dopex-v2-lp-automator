// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "./../../lib/UniswapV3SingleTickLiquidityLibV2.sol";

contract ReserveHelper {
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using EnumerableSet for EnumerableSet.UintSet;

    struct ReserveRequest {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
    }

    struct BatchWithdrawCache {
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams request;
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams position;
        uint256 tokenId;
        uint256 prev0;
        uint256 prev1;
    }

    mapping(uint256 tokenId => IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams position)
        public userReservedPositions;
    EnumerableSet.UintSet internal _reservedTokenIds;

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
        positions = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](_reservedTokenIds.length());

        for (uint256 i; i < positions.length; ) {
            positions[i] = userReservedPositions[_reservedTokenIds.at(i)];
            unchecked {
                i++;
            }
        }
    }

    function batchReserveLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        ReserveRequest[] calldata reserveRequests
    )
        external
        onlyProxy
        returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reservedPositions)
    {
        uint256 len = reserveRequests.length;
        reservedPositions = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](len);

        for (uint256 i; i < len; ) {
            uint256 tokenId = handler.tokenId(
                reserveRequests[i].pool,
                reserveRequests[i].hook,
                reserveRequests[i].tickLower,
                reserveRequests[i].tickUpper
            );

            uint128 shares = uint128(handler.balanceOf(user, tokenId));
            // reserve all user shares to withdraw.
            // shares are converted to liquidity in reserveLiquidity() function of handler
            uint128 assets = handler.convertToAssets(shares, tokenId);
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory newReserve = (reservedPositions[
                i
            ] = IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams(
                reserveRequests[i].pool,
                reserveRequests[i].hook,
                reserveRequests[i].tickLower,
                reserveRequests[i].tickUpper,
                // if the user is only LP provider at this tick, 1 liquidity shortage exists in handler.
                // because handler will mint 1 less liquidity than requested when first position mint,
                // therefore liquidity from convertToAssets() causes underflow when burning process
                assets > handler.tokenIds(tokenId).totalLiquidity // handler.convertToAssets(shares, tokenId) > handler.tokenIds(tokenId).totalLiquidity
                    ? shares - 1
                    : shares
            ));

            // if no shares to reserve, skip
            if (newReserve.shares == 0) {
                unchecked {
                    i++;
                }
                continue;
            }

            handler.transferFrom(user, address(this), tokenId, newReserve.shares);

            // this is update active list if not exist
            _reservedTokenIds.add(tokenId);

            // cache current position to save gas
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory totalReserve = userReservedPositions[
                tokenId
            ];
            uint128 prevShares = totalReserve.shares;
            // override with requested position, and add previous shares if exists
            totalReserve = newReserve;
            totalReserve.shares += prevShares;

            // update storage
            userReservedPositions[tokenId] = totalReserve;

            // execute reserve liquidity
            handler.reserveLiquidity(abi.encode(newReserve));

            emit ReserveLiquidity(user, handler, newReserve);

            unchecked {
                i++;
            }
        }

        return reservedPositions;
    }

    function batchWithdrawReservedLiquidity(IUniswapV3SingleTickLiquidityHandlerV2 handler) external onlyProxy {
        address _user = user;
        uint256 len = _reservedTokenIds.length();

        BatchWithdrawCache memory cache;

        uint256 withdrawable;

        for (uint256 i; i < len; ) {
            cache.request = userReservedPositions[_reservedTokenIds.at(i)];

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

            cache.position = userReservedPositions[cache.tokenId];
            cache.position.shares -= cache.request.shares;
            // if all shares are withdrawn, remove from active list
            if (cache.position.shares == 0) _reservedTokenIds.remove(cache.tokenId);

            // update storage
            userReservedPositions[cache.tokenId] = cache.position;

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
