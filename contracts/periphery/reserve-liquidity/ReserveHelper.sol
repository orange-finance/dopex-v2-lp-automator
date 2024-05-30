// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IStrykeHandlerV2} from "./IStrykeHandlerV2.sol";

error OnlyProxy();
error IncorrectHandler(IStrykeHandlerV2 handler);

contract ReserveHelper {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    mapping(uint256 tokenId => IStrykeHandlerV2.ReserveLiquidity position) public userReservedPositions;
    EnumerableSet.UintSet internal _reservedTokenIds;

    address public immutable user;
    address public immutable proxy;

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

        IStrykeHandlerV2.ReserveLiquidity memory userReserve = userReservedPositions[tokenId];
        if (userReserve.liquidity == 0) {
            _reservedTokenIds.add(tokenId);
            userReserve = reserveInLiquidity;
        } else {
            userReserve.liquidity += reserveInLiquidity.liquidity;
        }

        // update storage with updated struct to save gas
        userReservedPositions[tokenId] = userReserve;

        liquidityReserved = IStrykeHandlerV2.ReserveLiquidity(
            reserveInShare.pool,
            reserveInShare.hook,
            reserveInShare.tickLower,
            reserveInShare.tickUpper,
            reserveInLiquidity.liquidity
        );

        // all effect has done, transfer shares to this contract and execute reserve liquidity
        handler.transferFrom(user, address(this), tokenId, reserveInShare.shares);
        handler.reserveLiquidity(abi.encode(reserveInShare));
    }

    function withdrawReserveLiquidity(
        IStrykeHandlerV2 handler,
        uint256 tokenId
    ) external onlyProxy returns (IStrykeHandlerV2.ReserveLiquidity memory positionWithdrawn) {
        IStrykeHandlerV2.ReserveLiquidity memory withdraw = userReservedPositions[tokenId];
        IStrykeHandlerV2.ReserveLiquidity memory remaining = userReservedPositions[tokenId];

        // handler must be the same as the one used to reserve the liquidity
        // otherwise, withdraw call will waste gas for the external call even if the parameter is not valid,
        // or possibly revert unexpectedly in `_withdrawableLiquidity()`.
        if (_tokenId(handler, withdraw.pool, withdraw.hook, withdraw.tickLower, withdraw.tickUpper) != tokenId)
            revert IncorrectHandler(handler);

        // get actual withdrawable liquidity since some liquidity might be used by other users.
        withdraw.liquidity = _withdrawableLiquidity(handler, withdraw);
        if (withdraw.liquidity == 0) return IStrykeHandlerV2.ReserveLiquidity(address(0), address(0), 0, 0, 0);

        remaining.liquidity -= withdraw.liquidity;
        if (remaining.liquidity == 0) _reservedTokenIds.remove(tokenId);

        // update storage and return value
        userReservedPositions[tokenId] = remaining;
        positionWithdrawn = withdraw;

        IERC20 token0 = IERC20(IUniswapV3Pool(withdraw.pool).token0());
        IERC20 token1 = IERC20(IUniswapV3Pool(withdraw.pool).token1());

        handler.withdrawReserveLiquidity(abi.encode(withdraw));

        // transfer dissolved position to user
        // each ReserveHelper is dedicated to the user, so we can transfer all balance to the user.
        // token is accumulated in this contract when:
        // 1. call `handler.reserveLiquidity`, pool fee is transferred to this contract
        // 2. call `handler.withdrawReservedLiquidity`, the dissolved position in token0/1 is transferred to the user
        uint256 transfer;
        address _user = user;
        if ((transfer = token0.balanceOf(address(this))) > 0) token0.safeTransfer(_user, transfer);
        if ((transfer = token1.balanceOf(address(this))) > 0) token1.safeTransfer(_user, transfer);
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
