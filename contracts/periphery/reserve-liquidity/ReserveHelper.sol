// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IStrykeHandlerV2} from "./IStrykeHandlerV2.sol";

error OnlyProxy();

contract ReserveHelper {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 tokenId => IStrykeHandlerV2.ReserveLiquidity position) public userReservedPositions;
    EnumerableSet.UintSet internal _reservedTokenIds;

    address public user;
    address public proxy;

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

    function getReservedPositions() external view returns (IStrykeHandlerV2.ReserveLiquidity[] memory positions) {
        positions = new IStrykeHandlerV2.ReserveLiquidity[](_reservedTokenIds.length());

        for (uint256 i; i < positions.length; ) {
            positions[i] = userReservedPositions[_reservedTokenIds.at(i)];
            unchecked {
                i++;
            }
        }
    }

    function reserveLiquidity(
        IStrykeHandlerV2 handler,
        IStrykeHandlerV2.ReserveShare memory reserveInShare
    ) external onlyProxy returns (IStrykeHandlerV2.ReserveLiquidity memory liquidityReserved) {
        uint256 tokenId = _tokenId(
            handler,
            reserveInShare.pool,
            reserveInShare.hook,
            reserveInShare.tickLower,
            reserveInShare.tickUpper
        );

        // liquidity calculated here is the actual liquidity to reserve
        // after the call of `handler.reserveLiquidity`, `convertToAssets` returns the different liquidity as the handler totalSupply is already changed
        // uint128 liquidityToReserve = handler.convertToAssets(reservePosition.shares, tokenId);
        IStrykeHandlerV2.ReserveLiquidity memory reserveInLiquidity = IStrykeHandlerV2.ReserveLiquidity(
            reserveInShare.pool,
            reserveInShare.hook,
            reserveInShare.tickLower,
            reserveInShare.tickUpper,
            handler.convertToAssets(reserveInShare.shares, tokenId)
        );

        IStrykeHandlerV2.ReserveLiquidity memory totalReserve = userReservedPositions[tokenId];
        if (totalReserve.liquidity == 0) {
            _reservedTokenIds.add(tokenId);
            totalReserve = reserveInLiquidity;
        } else {
            totalReserve.liquidity += reserveInLiquidity.liquidity;
        }

        // update storage with updated struct to save gas
        userReservedPositions[tokenId] = totalReserve;

        // all effect has done, transfer shares to this contract and execute reserve liquidity
        handler.transferFrom(user, address(this), tokenId, reserveInShare.shares);
        handler.reserveLiquidity(abi.encode(reserveInShare));

        return
            IStrykeHandlerV2.ReserveLiquidity(
                reserveInShare.pool,
                reserveInShare.hook,
                reserveInShare.tickLower,
                reserveInShare.tickUpper,
                reserveInLiquidity.liquidity
            );
    }

    function withdrawReservedLiquidity(
        IStrykeHandlerV2 handler,
        // IStrykeHandlerV2.BurnPositionParams memory reservePosition
        uint256 tokenId
    ) external onlyProxy returns (IStrykeHandlerV2.ReserveLiquidity memory positionWithdrawn) {
        IStrykeHandlerV2.ReserveLiquidity memory request = userReservedPositions[tokenId];
        IStrykeHandlerV2.ReserveLiquidity memory position = userReservedPositions[tokenId];

        // get actual withdrawable liquidity.
        request.liquidity = _withdrawableLiquidity(handler, request);

        if (request.liquidity == 0) return IStrykeHandlerV2.ReserveLiquidity(address(0), address(0), 0, 0, 0);

        position.liquidity -= request.liquidity;
        // if all shares are withdrawn, remove from active list
        if (position.liquidity == 0) _reservedTokenIds.remove(tokenId);

        // update storage
        userReservedPositions[tokenId] = position;

        IERC20 token0 = IERC20(IUniswapV3Pool(request.pool).token0());
        IERC20 token1 = IERC20(IUniswapV3Pool(request.pool).token1());

        uint256 prev0 = token0.balanceOf(address(this));
        uint256 prev1 = token1.balanceOf(address(this));

        // we need cache the shares first
        handler.withdrawReserveLiquidity(abi.encode(request));

        // transfer dissolved position to user
        uint256 diff0 = token0.balanceOf(address(this)) - prev0;
        uint256 diff1 = token1.balanceOf(address(this)) - prev1;

        // not cache user address to memory. only one transfer should be done for the single tick position.
        if (diff0 > 0) token0.transfer(user, diff0);
        if (diff1 > 0) token1.transfer(user, diff1);
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
        IStrykeHandlerV2.ReserveLiquidity memory reservePosition
    ) internal view returns (uint128 withdrawable) {
        uint256 tokenId = _tokenId(
            handler,
            reservePosition.pool,
            reservePosition.hook,
            reservePosition.tickLower,
            reservePosition.tickUpper
        );
        IStrykeHandlerV2.ReserveLiquidityData memory rld = handler.reservedLiquidityPerUser(tokenId, address(this));

        IStrykeHandlerV2.TokenIdInfo memory tki = handler.tokenIds(tokenId);

        // if reserve cooldown has not passed. no withdrawable liquidity exists
        if (rld.lastReserve + handler.reserveCooldown() > block.timestamp) return 0;

        // if free liquidity of handler is not enough, return only available liquidity
        uint128 free = tki.totalLiquidity + tki.reservedLiquidity - tki.liquidityUsed;

        return free < reservePosition.liquidity ? free : reservePosition.liquidity;
    }
}
