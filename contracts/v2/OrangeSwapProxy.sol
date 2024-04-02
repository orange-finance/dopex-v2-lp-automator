// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeSwapProxy} from "./IOrangeSwapProxy.sol";

/**
 * @title OrangeSwapProxy
 * @dev A base contract implementation that acts as a proxy for executing swaps on various platforms.
 */
abstract contract OrangeSwapProxy is IOrangeSwapProxy {
    // solhint-disable-next-line const-name-snakecase
    uint256 public constant deltaScale = 10000;
    address public owner;
    mapping(address provider => bool) public trustedProviders;

    error Unauthorized();
    error OutOfDelta();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setTrustedProvider(address provider, bool trusted) external onlyOwner {
        trustedProviders[provider] = trusted;
    }

    function safeInputSwap(SwapInputRequest memory request) external virtual;
}
