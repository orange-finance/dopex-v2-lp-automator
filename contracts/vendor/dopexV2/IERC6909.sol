// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * @title ERC-6909: Interface for ERC-6909: Batch Transfers
 * @author Orange Finance
 * @notice This is the interface for the ERC-6909 implementation written in the transmissions11/solmate repository.
 * @dev implementation url: https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol
 */
interface IERC6909 {
    function isOperator(address holder, address operator) external view returns (bool);

    function balanceOf(address holder, uint256 tokenId) external view returns (uint256);

    function allowance(address holder, address spender) external view returns (uint256);

    function transfer(address receiver, uint256 id, uint256 amount) external;

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external;

    function approve(address spender, uint256 id, uint256 amount) external;

    function setOperator(address operator, bool approved) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
