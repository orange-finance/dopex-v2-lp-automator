// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBalancerFlashLoanRecipient} from "./vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {IBalancerVault} from "./vendor/balancer/IBalancerVault.sol";

abstract contract BalancerFlashLoanRecipient is IBalancerFlashLoanRecipient {
    IBalancerVault private immutable VAULT;

    error FlashLoan_Unauthorized();

    constructor(address vault) {
        VAULT = IBalancerVault(vault);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        if (msg.sender != address(VAULT)) revert FlashLoan_Unauthorized();

        _onFlashLoanReceived(tokens, amounts, feeAmounts, userData);
    }

    function _makeFlashLoan(IERC20[] memory tokens, uint256[] memory amounts, bytes memory userData) internal {
        VAULT.flashLoan(this, tokens, amounts, userData);
    }

    function _onFlashLoanReceived(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) internal virtual;
}
