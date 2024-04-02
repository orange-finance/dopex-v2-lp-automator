// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IOrangeSwapProxy
 * @dev Interface for the OrangeSwapProxy contract.
 */
interface IOrangeSwapProxy {
    /**
     * @dev Struct representing a swap input request.
     * @param provider The address of the provider.
     * @param swapCalldata The calldata for the swap.
     * @param expectTokenIn The input token for the swap.
     * @param expectTokenOut The output token for the swap.
     * @param expectAmountIn The expected amount of input token.
     * @param inputDelta The input delta value.
     */
    struct SwapInputRequest {
        address provider;
        bytes swapCalldata;
        IERC20 expectTokenIn;
        IERC20 expectTokenOut;
        uint256 expectAmountIn;
        uint256 inputDelta;
    }

    /**
     * @dev Returns the delta scale value which is used to calculate swap input delta.
     * @return The delta scale value.
     */
    function deltaScale() external view returns (uint256);

    /**
     * @dev Performs a safe input swap to prevent malicious swap request to the automator.
     * @param request The swap input request.
     */
    function safeInputSwap(SwapInputRequest memory request) external;
}
