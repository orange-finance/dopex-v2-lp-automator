// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IStrykeHandlerV2} from "./IStrykeHandlerV2.sol";

contract ReserveHelper {
    using EnumerableSet for EnumerableSet.UintSet;

    struct ReserveRequest {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
    }

    struct BatchWithdrawCache {
        IStrykeHandlerV2.BurnPositionParams request;
        IStrykeHandlerV2.BurnPositionParams position;
        uint256 prev0;
        uint256 prev1;
    }

    mapping(uint256 tokenId => IStrykeHandlerV2.BurnPositionParams position) public userReservedPositions;
    EnumerableSet.UintSet internal _reservedTokenIds;

    address public user;
    address public proxy;

    event ReserveLiquidity(
        address indexed user,
        IStrykeHandlerV2 handler,
        IStrykeHandlerV2.BurnPositionParams reservedPosition
    );
    event WithdrawReservedLiquidity(
        address indexed user,
        IStrykeHandlerV2 handler,
        IStrykeHandlerV2.BurnPositionParams reservedPosition
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

    function getReservedTokenIds() external view returns (uint256[] memory tokenIds) {
        tokenIds = _reservedTokenIds.values();
    }

    function getReservedPositions() external view returns (IStrykeHandlerV2.BurnPositionParams[] memory positions) {
        positions = new IStrykeHandlerV2.BurnPositionParams[](_reservedTokenIds.length());

        for (uint256 i; i < positions.length; ) {
            positions[i] = userReservedPositions[_reservedTokenIds.at(i)];
            unchecked {
                i++;
            }
        }
    }

    function batchReserveLiquidity(
        IStrykeHandlerV2 handler,
        ReserveRequest[] calldata reserveRequests
    ) external onlyProxy returns (IStrykeHandlerV2.BurnPositionParams[] memory reservedPositions) {
        uint256 len = reserveRequests.length;
        reservedPositions = new IStrykeHandlerV2.BurnPositionParams[](len);

        for (uint256 i; i < len; ) {
            uint256 tokenId = _tokenId(
                handler,
                reserveRequests[i].pool,
                reserveRequests[i].hook,
                reserveRequests[i].tickLower,
                reserveRequests[i].tickUpper
            );

            uint128 shares = uint128(IStrykeHandlerV2(handler).balanceOf(user, tokenId));
            // reserve all user shares to withdraw.
            // shares are converted to liquidity in reserveLiquidity() function of handler
            uint128 assets = handler.convertToAssets(shares, tokenId);
            IStrykeHandlerV2.BurnPositionParams memory newReserve = (reservedPositions[i] = IStrykeHandlerV2
                .BurnPositionParams(
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
            IStrykeHandlerV2.BurnPositionParams memory totalReserve = userReservedPositions[tokenId];
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

    /**
     * @notice Withdraw reserved liquidity.
     * @dev This function is used to withdraw reserved liquidity.
     * @param handler The handler of the liquidity pool.
     * @param tokenIds The token ids of the liquidity pool. which should be obtained from getReservedTokenIds() off-chain to reduce gas cost.
     */
    function batchWithdrawReservedLiquidity(IStrykeHandlerV2 handler, uint256[] memory tokenIds) external onlyProxy {
        address _user = user;
        uint256 len = tokenIds.length;

        BatchWithdrawCache memory cache;

        for (uint256 i; i < len; ) {
            uint256 tid = tokenIds[i];
            cache.request = userReservedPositions[tid];

            // in withdrawReservedLiquidity(), shares is actually means assets(liquidity)
            // so convert shares to assets before request
            cache.request.shares = handler.convertToAssets(cache.request.shares, tid);

            // get actual withdrawable liquidity.
            cache.request.shares = _withdrawableLiquidity(handler, cache.request);

            // condition has not met, skip
            if (cache.request.shares == 0) {
                unchecked {
                    i++;
                }
                continue;
            }

            cache.position = userReservedPositions[tid];
            cache.position.shares -= handler.convertToShares(cache.request.shares, tid);
            // if all shares are withdrawn, remove from active list
            if (cache.position.shares == 0) _reservedTokenIds.remove(tid);

            // update storage
            userReservedPositions[tid] = cache.position;

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

    function _tokenId(
        IStrykeHandlerV2 handler,
        address pool,
        address hook,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(handler, pool, hook, tickLower, tickUpper)));
    }

    function _withdrawableLiquidity(
        IStrykeHandlerV2 handler,
        IStrykeHandlerV2.BurnPositionParams memory reservePosition
    ) internal view returns (uint128 withdrawable) {
        IStrykeHandlerV2.ReserveLiquidityData memory rld = handler.reservedLiquidityPerUser(
            _tokenId(
                handler,
                reservePosition.pool,
                reservePosition.hook,
                reservePosition.tickLower,
                reservePosition.tickUpper
            ),
            address(this)
        );

        IStrykeHandlerV2.TokenIdInfo memory tki = handler.tokenIds(
            _tokenId(
                handler,
                reservePosition.pool,
                reservePosition.hook,
                reservePosition.tickLower,
                reservePosition.tickUpper
            )
        );

        // if reserve cooldown has not passed. no withdrawable liquidity exists
        if (rld.lastReserve + handler.reserveCooldown() > block.timestamp) return 0;

        // if free liquidity of handler is not enough, return only available liquidity
        uint128 free = tki.totalLiquidity + tki.reservedLiquidity - tki.liquidityUsed;

        return free < reservePosition.shares ? free : reservePosition.shares;
    }
}
