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

    // function test_calculateRebalanceSwapParamsInRebalance() public {
    // UniswapV3PoolLib.Position[] memory _mintPositions = new UniswapV3PoolLib.Position[](1);
    // _mintPositions[0].tickLower = -199310;
    // Automator.RebalanceSwapParams _swapAmounts = automator.calculateRebalanceSwapParamsInRebalance(_mintPositions, _burnPositions);
    // }

    // function test_rebalance_fromInitialState() public {
    //     Automator.RebalanceMintParams memory _mintParams = Automator.RebalanceMintParams({tick: -199310, liquidity: 0});

    //     Automator.RebalanceBurnParams memory _burnParams = Automator.RebalanceBurnParams({tick: -199310, shares: 0});

    //     Automator.RebalanceSwapParams memory _swapParams = Automator.RebalanceSwapParams({
    //         assetsShortage: 0,
    //         counterAssetsShortage: 0,
    //         maxCounterAssetsUseForSwap: 0,
    //         maxAssetsUseForSwap: 0
    //     });

    //     automator.rebalance(_mintParams, _burnParams, _swapParams);
    // }
}
