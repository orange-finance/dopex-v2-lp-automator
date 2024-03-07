// SPDX-License-Identifier: GPL-3.0

/* solhint-disable one-contract-per-file */

pragma solidity 0.8.19;

import {OrangeStrykeLPAutomatorV1_1} from "./../../contracts/OrangeStrykeLPAutomatorV1_1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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

// mock invalid implementation for upgrade. state variable from v1 is removed.
contract MockBadAutomatorV2 is UUPSUpgradeable {
    uint256 public foo;
    uint256 public bar;
    address public baz;

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override {}

    function initializeV2(uint256 foo_, uint256 bar_, address baz_) public reinitializer(2) {
        foo = foo_;
        bar = bar_;
        baz = baz_;
    }

    function newFunction() public view returns (uint256, uint256, address) {
        return (foo, bar, baz);
    }
}
