// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.sol";

contract TestRebalance is Fixture {
    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    // function test_calculateSwapAmountsInRebalance() public {
    // UniswapV3PoolLib.Position[] memory _mintPositions = new UniswapV3PoolLib.Position[](1);
    // _mintPositions[0].tickLower = -199310;
    // Automator.SwapAmounts _swapAmounts = automator.calculateSwapAmountsInRebalance(_mintPositions, _burnPositions);
    // }
}
