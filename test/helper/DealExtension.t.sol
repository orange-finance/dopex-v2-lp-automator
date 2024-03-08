// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/* solhint-disable const-name-snakecase */
import {Vm} from "forge-std/Vm.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);
}

abstract contract DealExtension {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IUSDC private constant usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    function dealUsdc(address to, uint256 amount) internal {
        vm.prank(IUSDC(usdc).masterMinter());
        IUSDC(usdc).configureMinter(address(this), amount);
        usdc.mint(to, amount);
    }
}
