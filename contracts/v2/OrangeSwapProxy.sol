// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeSwapProxy} from "./IOrangeSwapProxy.sol";

abstract contract OrangeSwapProxy is IOrangeSwapProxy {
    // solhint-disable-next-line const-name-snakecase
    uint256 public constant deltaScale = 10000;
    address public owner;
    mapping(address provider => bool) public trustedProviders;

    error Unauthorized();
    error InvalidAmount();

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

    function swapInput(SwapInputRequest memory request) external virtual;
}
