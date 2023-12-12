// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.sol";
import {IAutomator} from "../../contracts/interfaces/IAutomator.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract TestAutomatorRedeem is Fixture {
    using FixedPointMathLib for uint256;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_redeem_noDopexPosition() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1 ether);

        assertEq(WETH.balanceOf(alice), 0);

        vm.prank(alice);
        (uint256 _assets, IAutomator.LockedDopexShares[] memory _locked) = automator.redeem(1e18, 0);

        assertEq(_locked.length, 0);
        assertEq(_assets, 1 ether);
        assertEq(WETH.balanceOf(alice), 1 ether);
    }

    function test_redeem_burnDopexPositions() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1.3 ether);

        assertEq(WETH.balanceOf(alice), 0);

        uint256 _balanceBasedWeth = WETH.balanceOf(address(automator));
        uint256 _balanceBasedUsdce = _getQuote(address(WETH), address(USDCE), uint128(_balanceBasedWeth));

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        _mint(_balanceBasedWeth, _balanceBasedUsdce, _oor_belowLower, _oor_aboveLower);

        vm.startPrank(alice);
        (uint256 _assets, IAutomator.LockedDopexShares[] memory _locked) = automator.redeem(
            automator.balanceOf(alice),
            0
        );
        vm.stopPrank();

        assertEq(_locked.length, 0);
        assertApproxEqRel(_assets, 1.3 ether, 0.0005e18); // max 0.05% diff (swap fee)
        assertApproxEqRel(WETH.balanceOf(alice), 1.3 ether, 0.0005e18); // max 0.05% diff (swap fee)
    }

    function test_redeem_dopexPositionPartiallyLocked() public {
        deal(address(WETH), alice, 1.3 ether);
        deal(address(WETH), bob, 1 ether);

        // bob does first deposit, taking slippage from dead shares (makes it easier to redeem test for alice)
        vm.startPrank(bob);
        WETH.approve(address(automator), 1 ether);
        automator.deposit(1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        WETH.approve(address(automator), 1.3 ether);
        uint256 _shareAlice = automator.deposit(1.3 ether);
        vm.stopPrank();

        assertEq(WETH.balanceOf(alice), 0);

        uint256 _balanceBasedWeth = WETH.balanceOf(address(automator));
        uint256 _balanceBasedUsdce = _getQuote(address(WETH), address(USDCE), uint128(_balanceBasedWeth));

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        _mint(_balanceBasedWeth, _balanceBasedUsdce, _oor_belowLower, _oor_aboveLower);

        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _tokenIdInfo = _tokenInfo(_oor_belowLower);
        uint256 _freeLiquidity = _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed;

        _useDopexPosition(_oor_belowLower, _oor_belowLower + pool.tickSpacing(), uint128(_freeLiquidity - 1000));

        uint256 _balExpected = automator.freeAssets().mulDivDown(_shareAlice, automator.totalSupply());

        vm.startPrank(alice);
        (uint256 _assets, IAutomator.LockedDopexShares[] memory _locked) = automator.redeem(_shareAlice, 0);
        vm.stopPrank();

        assertEq(_locked.length, 1);
        assertApproxEqAbs(_assets, _balExpected, 1);
    }

    function test_redeem_revertWhenMinAssetsNotReached() public {
        deal(address(WETH), alice, 1 ether);
        deal(address(WETH), bob, 1 ether);

        // bob does first deposit, taking slippage from dead shares (makes it easier to redeem test for alice)
        vm.startPrank(bob);
        WETH.approve(address(automator), 1 ether);
        automator.deposit(1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        WETH.approve(address(automator), 1 ether);
        // 1e18 shares will minted
        automator.deposit(1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Automator.MinAssetsRequired.selector, 1.1 ether, 1 ether));
        automator.redeem(1 ether, 1.1 ether);
        vm.stopPrank();
    }

    function test_redeem_revertWhenSharesTooSmall() public {
        deal(address(WETH), alice, 1 ether);
        deal(address(WETH), bob, 1 ether);

        // bob does first deposit, taking slippage from dead shares (makes it easier to redeem test for alice)
        vm.startPrank(bob);
        WETH.approve(address(automator), 1 ether);
        automator.deposit(1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        WETH.approve(address(automator), 1 ether);
        // 1e18 shares will minted
        automator.deposit(1 ether);
        vm.stopPrank();

        // assume that significant amount of WETH locked as Dopex position
        vm.prank(address(automator));
        WETH.transfer(makeAddr("locked"), 2 ether - 1);

        /**
         * total supply: 2e18
         * alice shares: 1e18
         * WETH in automator: 1e18
         *
         * 1 * 1e18 / 2e18 = 0 shares
         *
         */

        vm.startPrank(alice);
        vm.expectRevert(Automator.SharesTooSmall.selector);
        automator.redeem(1e18, 0);
        vm.stopPrank();
    }

    function _mint(uint256 _amountWeth, uint256 _amountUsdce, int24 _oor_belowLower, int24 _oor_aboveLower) public {
        IAutomator.RebalanceTickInfo[] memory _ticksMint = new IAutomator.RebalanceTickInfo[](2);

        // token0: WETH, token1: USDCE
        _ticksMint[0] = IAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                0,
                (_amountUsdce / 2) - (_amountUsdce / 2).mulDivDown(pool.fee(), 1e6 - pool.fee())
            )
        });
        _ticksMint[1] = IAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                (_amountWeth / 2) - (_amountWeth / 2).mulDivDown(pool.fee(), 1e6 - pool.fee()),
                0
            )
        });

        IAutomator.RebalanceTickInfo[] memory _ticksBurn = new IAutomator.RebalanceTickInfo[](0);

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            automator.calculateRebalanceSwapParamsInRebalance(_ticksMint, _ticksBurn)
        );
    }
}
