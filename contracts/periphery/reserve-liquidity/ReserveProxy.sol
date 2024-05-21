// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

import {ReserveHelper} from "./ReserveHelper.sol";

contract ReserveProxy {
    mapping(bytes32 helperId => ReserveHelper) public reserveHelpers;

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

    error ReserveHelperAlreadyInitialized(address user, IUniswapV3SingleTickLiquidityHandlerV2 handler);
    error ReserveHelperUninitialized(address user, IUniswapV3SingleTickLiquidityHandlerV2 handler);

    function helperId(address user, IUniswapV3SingleTickLiquidityHandlerV2 handler) public pure returns (bytes32) {
        return keccak256(abi.encode(user, handler));
    }

    /**
     * @dev Creates a new reserve helper for the given handler and user.
     * @param handler The handler to create the reserve helper for.
     * @return reserveHelper The new reserve helper.
     */
    function createMyReserveHelper(
        IUniswapV3SingleTickLiquidityHandlerV2 handler
    ) external returns (ReserveHelper reserveHelper) {
        if (address(reserveHelper) != address(0)) revert ReserveHelperAlreadyInitialized(msg.sender, handler);
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
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        ReserveHelper.ReserveRequest[] calldata reserveLiquidityParams
    ) external returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reservedLiquidities) {
        ReserveHelper reserveHelper = reserveHelpers[helperId(msg.sender, handler)];
        if (address(reserveHelper) == address(0)) revert ReserveHelperUninitialized(msg.sender, handler);

        return reserveHelper.batchReserveLiquidity(handler, reserveLiquidityParams);
    }

    function batchWithdrawReserveLiquidity(
        IUniswapV3SingleTickLiquidityHandlerV2 handler,
        uint256[] calldata tokenIds
    ) external {
        ReserveHelper reserveHelper = reserveHelpers[helperId(msg.sender, handler)];
        if (address(reserveHelper) == address(0)) revert ReserveHelperUninitialized(msg.sender, handler);

        reserveHelper.batchWithdrawReservedLiquidity(handler, tokenIds);
    }
}
