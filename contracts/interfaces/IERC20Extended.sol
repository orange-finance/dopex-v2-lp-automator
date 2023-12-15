// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

interface IERC20Symbol {
    function symbol() external view returns (string memory);
}
