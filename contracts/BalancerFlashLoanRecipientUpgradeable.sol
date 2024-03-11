// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBalancerFlashLoanRecipient} from "./vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {IBalancerVault} from "./vendor/balancer/IBalancerVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract BalancerFlashLoanRecipientUpgradeable is IBalancerFlashLoanRecipient, Initializable {
    IBalancerVault private _vault;

    error FlashLoan_Unauthorized();

    // solhint-disable-next-line func-name-mixedcase
    function __BalancerFlashLoanRecipient_init(IBalancerVault vault) internal onlyInitializing {
        _vault = vault;
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        if (msg.sender != address(_vault)) revert FlashLoan_Unauthorized();

        _onFlashLoanReceived(tokens, amounts, feeAmounts, userData);
    }

    function _makeFlashLoan(IERC20[] memory tokens, uint256[] memory amounts, bytes memory userData) internal {
        _vault.flashLoan(this, tokens, amounts, userData);
    }

    function _onFlashLoanReceived(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) internal virtual;
}
