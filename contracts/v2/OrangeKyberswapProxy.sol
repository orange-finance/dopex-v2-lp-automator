// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OrangeSwapProxy} from "./OrangeSwapProxy.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {Decoder} from "./../lib/Decoder.sol";

/**
 * @title OrangeKyberswapProxy
 * @dev A contract that acts as a proxy for executing swaps on the KyberSwap platform.
 */
contract OrangeKyberswapProxy is OrangeSwapProxy {
    using Address for address;
    using SafeERC20 for IERC20;

    struct SwapDescriptionV2 {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers; // transfer src token to these addresses, default
        uint256[] srcAmounts;
        address[] feeReceivers;
        uint256[] feeAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct SwapExecutionParams {
        address callTarget;
        address approveTarget;
        bytes targetData;
        SwapDescriptionV2 desc;
        bytes clientData;
    }

    error InvalidFormat();
    error UnsupportedSelector();
    error SrcTokenDoesNotMatch();
    error DstTokenDoesNotMatch();
    error ReceiverIsNotSender();

    /**
     * @dev Executes a safe input swap on the KyberSwap platform.
     * @param request The swap request parameters.
     */
    function safeInputSwap(SwapInputRequest memory request) external override {
        // authorize router
        if (!trustedProviders[request.provider]) revert Unauthorized();

        // extract swap params
        (bytes4 selector, bytes memory args) = Decoder.calldataDecode(request.swapCalldata);

        // check if the selector is supported
        if (selector != 0xe21fd0e9) revert UnsupportedSelector();

        // decode as SwapExecutionParams layout
        SwapExecutionParams memory params = abi.decode(args, (SwapExecutionParams));

        // check if the token addresses match
        if (params.desc.srcToken != request.expectTokenIn) revert SrcTokenDoesNotMatch();
        if (params.desc.dstToken != request.expectTokenOut) revert DstTokenDoesNotMatch();

        // check if the destination receiver is match
        if (params.desc.dstReceiver != msg.sender) revert ReceiverIsNotSender();

        // check if the amount is within the expected range
        uint256 swapDelta = deltaScale + request.inputDelta;
        uint256 _min = FullMath.mulDiv(request.expectAmountIn * 1e18, deltaScale, swapDelta);
        uint256 _max = FullMath.mulDiv(request.expectAmountIn * 1e18, swapDelta, deltaScale);
        if (params.desc.amount * 1e18 < _min || params.desc.amount * 1e18 > _max) revert OutOfDelta();

        // receive expectTokenIn from msg.sender
        IERC20(request.expectTokenIn).safeTransferFrom(msg.sender, address(this), params.desc.amount);

        // approve kyberswap router to spend expectTokenIn
        if (request.expectTokenIn.allowance(address(this), request.provider) == 0) {
            request.expectTokenIn.forceApprove(request.provider, type(uint256).max);
        }

        // we also need to approve expectTokenOut because in some cases, part of the output may be taken as fee
        if (request.expectTokenOut.allowance(address(this), request.provider) == 0) {
            request.expectTokenOut.forceApprove(request.provider, type(uint256).max);
        }

        // execute swap
        // output is directly sent to msg.sender
        request.provider.functionCall(request.swapCalldata, "OrangeKyberSwapProxy: low-level call failed");
    }
}
