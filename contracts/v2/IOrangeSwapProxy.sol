// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOrangeSwapProxy {
    struct SwapInputRequest {
        address provider;
        bytes swapCalldata;
        IERC20 expectTokenIn;
        IERC20 expectTokenOut;
        uint256 expectAmountIn;
        uint256 inputDelta;
    }
    function deltaScale() external view returns (uint256);

    function safeInputSwap(SwapInputRequest memory request) external;
}
