// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ReserveHelper} from "./ReserveHelper.sol";
import {IStrykeHandlerV2} from "./IStrykeHandlerV2.sol";

error ReserveHelperAlreadyInitialized(address user, IStrykeHandlerV2 handler);
error ReserveHelperUninitialized(address user, IStrykeHandlerV2 handler);

contract ReserveProxy {
    mapping(bytes32 helperId => ReserveHelper) public reserveHelpers;

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

    function helperId(address user, IStrykeHandlerV2 handler) public pure returns (bytes32) {
        return keccak256(abi.encode(user, handler));
    }

    /**
     * @dev Creates a new reserve helper for the given handler and user.
     * @param handler The handler to create the reserve helper for.
     * @return reserveHelper The new reserve helper.
     */
    function createMyReserveHelper(IStrykeHandlerV2 handler) external returns (ReserveHelper reserveHelper) {
        if (address(reserveHelpers[helperId(msg.sender, handler)]) != address(0))
            revert ReserveHelperAlreadyInitialized(msg.sender, handler);
        reserveHelper = new ReserveHelper(msg.sender);
        reserveHelpers[helperId(msg.sender, handler)] = reserveHelper;
    }

    /**
     * @dev Batch reserves liquidity for the given handler and user.
     * @dev to use this function:
     * 1. Create a new reserve helper for the given handler and user.
     * 2. Set the initialized helper as the operator for the handler using `setOperator` function.
     * @param handler The handler to batch reserve liquidity for.
     * @param reserveLiquidityParams The parameters for the reserve liquidity.
     * @return reservedLiquidities The reserved liquidities.
     */
    function batchReserveLiquidity(
        IStrykeHandlerV2 handler,
        IStrykeHandlerV2.BurnPositionParams[] calldata reserveLiquidityParams
    ) external returns (IStrykeHandlerV2.BurnPositionParams[] memory reservedLiquidities) {
        ReserveHelper reserveHelper = reserveHelpers[helperId(msg.sender, handler)];
        if (address(reserveHelper) == address(0)) revert ReserveHelperUninitialized(msg.sender, handler);

        reservedLiquidities = new IStrykeHandlerV2.BurnPositionParams[](reserveLiquidityParams.length);

        for (uint256 i; i < reserveLiquidityParams.length; ) {
            IStrykeHandlerV2.BurnPositionParams memory reserve = reserveLiquidityParams[i];
            uint256 tokenId = _tokenId(handler, reserve.pool, reserve.hook, reserve.tickLower, reserve.tickUpper);

            uint128 assets = handler.convertToAssets(reserve.shares, tokenId);
            // if the user is only LP provider at this tick, 1 liquidity shortage exists in handler.
            // because handler will mint 1 less liquidity than requested when first position mint,
            // therefore liquidity from convertToAssets() causes underflow when burning process
            reserve.shares = assets > handler.tokenIds(tokenId).totalLiquidity ? reserve.shares - 1 : reserve.shares;
            reservedLiquidities[i] = reserve;

            // incase the sender is the only provider of the position and holding only 1 share, share will be 0
            if (reserve.shares == 0) continue;

            reserveHelper.reserveLiquidity(handler, reserve);

            emit ReserveLiquidity(msg.sender, handler, reserve);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Withdraws the reserved liquidity for the given handler and user. user specifies tokenIds, then helper will withdraw the liquidity for each position.
     * @dev each withdrawable liquidity amount is stored in the helper storage. you can only pass the tokenIds that are stored in the helper storage.
     * @dev tokenIds can be obtained by calling `getReservedTokenIds` function of the helper.
     * @param handler The handler to withdraw the reserved liquidity for.
     * @param tokenIds The token ids of the positions to withdraw the reserved liquidity for.
     */
    function batchWithdrawReserveLiquidity(IStrykeHandlerV2 handler, uint256[] calldata tokenIds) external {
        ReserveHelper reserveHelper = reserveHelpers[helperId(msg.sender, handler)];
        if (address(reserveHelper) == address(0)) revert ReserveHelperUninitialized(msg.sender, handler);

        for (uint256 i; i < tokenIds.length; ) {
            IStrykeHandlerV2.BurnPositionParams memory withdrawn = reserveHelper.withdrawReservedLiquidity(
                handler,
                tokenIds[i]
            );

            // emit the event only if the shares are greater than 0, to avoid invalid indexing occurs on the subgraph
            if (withdrawn.shares > 0) emit WithdrawReservedLiquidity(msg.sender, handler, withdrawn);

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
}
