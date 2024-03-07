// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {OrangeStrykeLPAutomatorV1_1} from "./../../contracts/OrangeStrykeLPAutomatorV1_1.sol";

contract MockAutomatorV2 is OrangeStrykeLPAutomatorV1_1 {
    uint256 public foo;
    uint256 public bar;
    address public baz;

    function initializeV2(uint256 foo_, uint256 bar_, address baz_) public reinitializer(2) {
        foo = foo_;
        bar = bar_;
        baz = baz_;
    }

    function newFunction() public view returns (uint256, uint256, address) {
        return (foo, bar, baz);
    }
}
