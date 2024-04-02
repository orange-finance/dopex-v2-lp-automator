// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeSwapProxy} from "contracts/v2/IOrangeSwapProxy.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Decoder} from "contracts/lib/Decoder.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockSwapProxy is IOrangeSwapProxy {
    uint256 public deltaScale = 10000;

    function safeInputSwap(SwapInputRequest memory request) external override {
        (bytes4 selector, bytes memory data) = Decoder.calldataDecode(request.swapCalldata);
        ISwapRouter.ExactInputSingleParams memory params = abi.decode(data, (ISwapRouter.ExactInputSingleParams));

        // amount in calculated by the automator is slightly larger than the pre-calculated amount in the swap calldata
        // because of receiving some extra tokens from burnt positions
        if (request.expectAmountIn > params.amountIn) params.amountIn = request.expectAmountIn;

        IERC20(params.tokenIn).approve(request.provider, params.amountIn);

        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        ISwapRouter(request.provider).exactInputSingle(params);
    }
}
