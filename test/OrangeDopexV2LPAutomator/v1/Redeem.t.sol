// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, var-name-mixedcase */
import {Fixture, stdStorage, StdStorage} from "./Fixture.t.sol";
import {AutomatorHelper} from "../../helper/AutomatorHelper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {IERC6909} from "../../../contracts/vendor/dopexV2/IERC6909.sol";
import {IOrangeDopexV2LPAutomatorV1} from "../../../contracts/interfaces/IOrangeDopexV2LPAutomatorV1.sol";
import {OrangeDopexV2LPAutomatorV1} from "./../../../contracts/OrangeDopexV2LPAutomatorV1.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract TestOrangeDopexV2LPAutomatorV1Redeem is Fixture {
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_redeem_noDopexPosition() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1 ether);

        assertEq(WETH.balanceOf(alice), 0);

        vm.prank(alice);
        (uint256 _assets, IOrangeDopexV2LPAutomatorV1.LockedDopexShares[] memory _locked) = automator.redeem(1e18, 0);

        assertEq(_locked.length, 0);
        assertEq(_assets, 1 ether);
        assertEq(WETH.balanceOf(alice), 1 ether);
    }

    function test_redeem_burnDopexPositions() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1.3 ether);

        assertEq(WETH.balanceOf(alice), 0);

        uint256 _balanceBasedWeth = WETH.balanceOf(address(automator));
        uint256 _balanceBasedUsdc = _getQuote(address(WETH), address(USDC), uint128(_balanceBasedWeth));

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        _mint(_balanceBasedWeth, _balanceBasedUsdc, _oor_belowLower, _oor_aboveLower);

        vm.startPrank(alice);
        (uint256 _assets, IOrangeDopexV2LPAutomatorV1.LockedDopexShares[] memory _locked) = automator.redeem(automator.balanceOf(alice), 0); // prettier-ignore
        vm.stopPrank();

        assertEq(_locked.length, 0);
        assertApproxEqRel(_assets, 1.3 ether, 0.0005e18); // max 0.05% diff (swap fee)
        assertApproxEqRel(WETH.balanceOf(alice), 1.3 ether, 0.0005e18); // max 0.05% diff (swap fee)
    }

    function test_redeem_dopexPositionFullyLocked() public {
        // current tick: -196791

        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1.3 ether);

        // mint dopex position using 1.3 WETH
        // liquidity(-196780, -196770, 1.3 WETH, 0 USDC.e) = 138769446144582646
        _rebalanceMintSingle(-196780, 138769446144582646);

        // use all liquidity in dopex (can be calculated from TokenIdInfo.totalLiquidity - TokenIdInfo.liquidityUsed)
        // _useDopexPosition(-196780, -196770, 138769446144582645);
        pool.useDopexPosition(emptyHook, -196780, 138769446144582645);

        // now the balance of WETH in automator ≈ 1 ether
        vm.prank(alice);
        (uint256 _assets, IOrangeDopexV2LPAutomatorV1.LockedDopexShares[] memory _locked) = automator.redeem(1.3 ether, 0); // prettier-ignore

        // 1.3 ether * 1 ether (redeemable WETH in automator) / 2.3 ether(automator total supply) = 565217391304347826
        // some error in calculation because WETH is not actually used to mint dopex position as expected (less amount is used)
        assertApproxEqRel(_assets, 565217391304347826, 0.0001e18); // allow 0.01% diff
        assertEq(_locked.length, 1);

        // keccak256(abi.encode(uniV3Handler, pool, hook, -199330, -199320))
        assertEq(_locked[0].tokenId, 51731724170277633442520037625677593345052024787730572352688588083216565283241);

        // 138769446144582645 (automator's locked shares) * 1.3 ether (redeemable WETH in automator) / 2.3 ether (automator total supply)
        assertEq(_locked[0].shares, 78434904342590190);
        assertEq(
            IERC6909(address(uniV3Handler)).balanceOf(alice, 51731724170277633442520037625677593345052024787730572352688588083216565283241), // prettier-ignore
            78434904342590190
        );
    }

    function test_redeem_dopexPositionPartiallyLocked() public {
        // current tick: -196791
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1.3 ether);

        // mint dopex position using 1.3 WETH
        // liquidity(-196780, -196770, 1.3 WETH, 0 USDC.e) = 138769446144582646
        _rebalanceMintSingle(-196780, 138769446144582646);

        // use half of liquidity in dopex
        // now the redeemable WETH in automator = 1.65 WETH (2.3 WETH - 1.3 / 2 WETH)
        pool.useDopexPosition(emptyHook, -196780, 69384723072291323);

        // redeem alice's all shares
        vm.prank(alice);
        (uint256 _assets, IOrangeDopexV2LPAutomatorV1.LockedDopexShares[] memory _locked) = automator.redeem(1.3e18, 0); // prettier-ignore

        // 1.3e18 * 1.65 WETH (redeemable WETH in automator) / 2.3e18 (automator total supply) = 932608695652173913
        // some error in calculation because WETH is not actually used to mint dopex position as expected (less amount is used)
        assertApproxEqRel(_assets, 932608695652173913, 0.0001e18); // allow 0.01% diff
        assertEq(_locked.length, 1);

        // alice locked shares = 69384723072291323 (automator's locked shares) * 1.3e18 (share of alice) / 2.3e18(automator total supply)
        assertEq(
            IERC6909(address(uniV3Handler)).balanceOf(alice, 51731724170277633442520037625677593345052024787730572352688588083216565283241), // prettier-ignore
            39217452171295095
        );
    }

    function test_redeem_dopexHandlerPaused() public {
        // current tick: -196791
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1.3 ether);

        // mint dopex position using 1.3 WETH
        // liquidity(-196780, -196770, 1.3 WETH, 0 USDC.e) = 138769446144582646
        _rebalanceMintSingle(-196780, 138769446144582646);

        // set handler paused
        stdstore.target(address(uniV3Handler)).sig("paused()").checked_write(true);

        // now the balance of WETH in automator ≈ 1 ether
        vm.prank(alice);
        (uint256 _assets, ) = automator.redeem(1.3 ether, 0);

        // 1.3 ether * 1 ether (redeemable WETH in automator) / 2.3 ether(automator total supply) = 565217391304347826
        assertApproxEqRel(_assets, 565217391304347826, 0.0001e18); // allow 0.01% diff
        assertApproxEqRel(WETH.balanceOf(alice), 565217391304347826, 0.0001e18); // allow 0.01% diff

        // 1.3 ether * 138769446144582646 (automator total handler shares) / 2.3 ether (automator total supply) = 78434904342590191
        assertApproxEqRel(
            DopexV2Helper.balanceOfHandler(alice, pool, emptyHook, -196780),
            78434904342590191,
            0.0001e18 // allow 0.01% diff
        );
    }

    function test_redeem_revertWhenMinAssetsNotReached() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1 ether);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(OrangeDopexV2LPAutomatorV1.MinAssetsRequired.selector, 1.1 ether, 1 ether)
        );
        automator.redeem(1 ether, 1.1 ether);
        vm.stopPrank();
    }

    function test_redeem_revertWhenSharesTooSmall() public {
        _depositFrom(bob, 1 ether);
        _depositFrom(alice, 1 ether);

        // assume that significant amount of WETH locked as Dopex position
        vm.prank(address(automator));
        WETH.transfer(makeAddr("locked"), 2 ether - 1);

        // total supply: 2e18
        // alice shares: 1e18
        // WETH in automator: 1e18
        //
        // 1 * 1e18 / 2e18 = 0 shares
        vm.startPrank(alice);
        vm.expectRevert(OrangeDopexV2LPAutomatorV1.SharesTooSmall.selector);
        automator.redeem(1e18, 0);
        vm.stopPrank();
    }

    function _mint(uint256 _amountWeth, uint256 _amountUsdc, int24 _oor_belowLower, int24 _oor_aboveLower) public {
        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](2);

        // token0: WETH, token1: USDC
        _ticksMint[0] = IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                0,
                (_amountUsdc / 2) - (_amountUsdc / 2).mulDivDown(pool.fee(), 1e6 - pool.fee())
            )
        });
        _ticksMint[1] = IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                (_amountWeth / 2) - (_amountWeth / 2).mulDivDown(pool.fee(), 1e6 - pool.fee()),
                0
            )
        });

        IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[]
            memory _ticksBurn = new IOrangeDopexV2LPAutomatorV1.RebalanceTickInfo[](0);

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            AutomatorHelper.calculateRebalanceSwapParamsInRebalance(automator, pool, WETH, USDC, _ticksMint, _ticksBurn)
        );
    }
}
