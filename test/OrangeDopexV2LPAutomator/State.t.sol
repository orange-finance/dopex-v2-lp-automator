// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Fixture.t.sol";
import {IOrangeDopexV2LPAutomator} from "../../contracts/interfaces/IOrangeDopexV2LPAutomator.sol";
import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";
import {OrangeDopexV2LPAutomator, deployAutomatorHarness, AutomatorHarness} from "./harness/AutomatorHarness.t.sol";
import "../helper/AutomatorHelper.t.sol";

contract TestOrangeDopexV2LPAutomatorState is Fixture {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandler;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_totalAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDCE = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        deal(address(USDCE), address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDCE), address(WETH), uint128(_balanceUSDCE));

        assertEq(automator.totalAssets(), _expected);
    }

    function test_totalAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDCE), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });
        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _assetsInOrangeDopexV2LPAutomator = WETH.balanceOf(address(automator)) +
            _getQuote(address(USDCE), address(WETH), uint128(USDCE.balanceOf(address(automator))));

        emit log_named_uint("assets in automator", _assetsInOrangeDopexV2LPAutomator);

        // allow bit of error because rounding will happen from different position => assets calculations
        assertApproxEqAbs(
            automator.totalAssets(),
            _assetsInOrangeDopexV2LPAutomator +
                _positionToAssets(_oor_belowLower, address(automator)) +
                _positionToAssets(_oor_aboveLower, address(automator)),
            1
        );
    }

    function test_totalAssets_reversedPair() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        deal(address(USDCE), address(automator), 100e6);

        assertEq(automator.totalAssets(), 100e6);
    }

    function test_convertToAssets_noDopexPosition() public {
        /*///////////////////////////////////////////////////////
                        case: 1 depositor (single token)
        ///////////////////////////////////////////////////////*/
        uint256 _aliceDeposit = 1.3 ether;
        uint256 _deadInFirstDeposit = 10 ** automator.decimals() / 1000;

        deal(address(WETH), alice, _aliceDeposit);

        vm.startPrank(alice);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _aliceShares = automator.deposit(_aliceDeposit);

        assertEq(
            automator.convertToAssets(_aliceShares),
            _aliceDeposit - automator.convertToAssets(_deadInFirstDeposit),
            "first deposit"
        );

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDCE), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDCE), address(WETH), uint128(_usdceInVault));

        assertApproxEqAbs(automator.convertToAssets(_aliceShares), _aliceAssets, 1, "automator allocation changed");

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);

        assertApproxEqAbs(automator.convertToAssets(_bobShares), _bobDeposit, 1, "bob entered");
        assertApproxEqAbs(automator.convertToAssets(_aliceShares), _aliceAssets, 1, "alice assets unchanged");
    }

    function test_convertToAssets_hasDopexPositions() public {
        /*///////////////////////////////////////////////////////
                        case: 1 depositor (single token)
        ///////////////////////////////////////////////////////*/
        uint256 _aliceDeposit = 1.3 ether;
        uint256 _deadInFirstDeposit = 10 ** automator.decimals() / 1000;

        deal(address(WETH), alice, _aliceDeposit);

        vm.startPrank(alice);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _aliceShares = automator.deposit(_aliceDeposit);
        vm.stopPrank();

        assertEq(
            automator.convertToAssets(_aliceShares),
            _aliceDeposit - automator.convertToAssets(_deadInFirstDeposit),
            "first deposit"
        );

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDCE), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDCE), address(WETH), uint128(_usdceInVault));

        assertApproxEqAbs(automator.convertToAssets(_aliceShares), _aliceAssets, 1, "automator allocation changed");

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqAbs(automator.convertToAssets(_bobShares), _bobDeposit, 1, "bob entered");
        assertApproxEqAbs(automator.convertToAssets(_aliceShares), _aliceAssets, 1, "alice assets unchanged");

        /*///////////////////////////////////////////////////////
                        case: dopex position minted
        ///////////////////////////////////////////////////////*/

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        assertEq(
            automator.convertToAssets(_aliceShares),
            (_aliceShares * automator.totalAssets()) / automator.totalSupply(),
            "alice assets includes dopex positions"
        );

        assertEq(
            automator.convertToAssets(_bobShares),
            (_bobShares * automator.totalAssets()) / automator.totalSupply(),
            "bob assets includes dopex positions"
        );
    }

    function test_freeAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDCE = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        deal(address(USDCE), address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDCE), address(WETH), uint128(_balanceUSDCE));

        assertEq(automator.freeAssets(), _expected);
    }

    function test_freeAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDCE), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 4;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 4;

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });
        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _assetsInOrangeDopexV2LPAutomator = WETH.balanceOf(address(automator)) +
            _getQuote(address(USDCE), address(WETH), uint128(USDCE.balanceOf(address(automator))));
        uint256 _freeAssets = _assetsInOrangeDopexV2LPAutomator +
            _positionToAssets(_oor_belowLower, address(automator)) +
            _positionToAssets(_oor_aboveLower, address(automator));

        assertEq(automator.freeAssets(), _freeAssets);
    }

    function test_freeAssets_reversedPair() public {
        automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        deal(address(USDCE), address(automator), 100e6);

        assertEq(automator.freeAssets(), 100e6);
    }

    function test_convertToShares_noDopexPosition() public {
        /*///////////////////////////////////////////////////////
                        case: 1 depositor (single token)
        ///////////////////////////////////////////////////////*/
        uint256 _aliceDeposit = 1.3 ether;
        uint256 _deadInFirstDeposit = 10 ** automator.decimals() / 1000;

        deal(address(WETH), alice, _aliceDeposit);

        vm.startPrank(alice);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _aliceShares = automator.deposit(_aliceDeposit);
        vm.stopPrank();

        assertEq(automator.convertToShares(1.3 ether), _aliceShares + _deadInFirstDeposit, "first deposit");

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDCE), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDCE), address(WETH), uint128(_usdceInVault));

        assertEq(automator.convertToShares(_aliceAssets), _aliceShares, "automator allocation changed");

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqAbs(automator.convertToShares(_bobDeposit), _bobShares, 1, "bob entered");
        assertApproxEqAbs(automator.convertToShares(_aliceAssets), _aliceShares, 1, "alice assets unchanged");
    }

    function test_convertToShares_hasDopexPositions() public {
        /*///////////////////////////////////////////////////////
                        case: 1 depositor (single token)
        ///////////////////////////////////////////////////////*/
        uint256 _aliceDeposit = 1.3 ether;
        uint256 _deadInFirstDeposit = 10 ** automator.decimals() / 1000;

        deal(address(WETH), alice, _aliceDeposit);

        vm.startPrank(alice);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _aliceShares = automator.deposit(_aliceDeposit);
        vm.stopPrank();

        assertEq(automator.convertToShares(1.3 ether), _aliceShares + _deadInFirstDeposit, "first deposit");

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDCE), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDCE), address(WETH), uint128(_usdceInVault));

        assertEq(automator.convertToShares(_aliceAssets), _aliceShares, "automator allocation changed");

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqAbs(automator.convertToShares(_bobDeposit), _bobShares, 1, "bob entered");
        assertApproxEqAbs(automator.convertToShares(_aliceAssets), _aliceShares, 1, "alice assets unchanged");

        /*///////////////////////////////////////////////////////
                        case: dopex position minted
        ///////////////////////////////////////////////////////*/

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                WETH.balanceOf(address(automator)) / 3,
                USDCE.balanceOf(address(automator)) / 3
            )
        });

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                WETH.balanceOf(address(automator)) / 3,
                USDCE.balanceOf(address(automator)) / 3
            )
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        assertApproxEqAbs(
            automator.convertToShares((_aliceShares * automator.totalAssets()) / automator.totalSupply()),
            _aliceShares,
            1,
            "alice shares includes dopex positions"
        );

        assertApproxEqAbs(
            automator.convertToShares((_bobShares * automator.totalAssets()) / automator.totalSupply()),
            _bobShares,
            1,
            "bob shares includes dopex positions"
        );
    }

    function test_getTickAllLiquidity() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDCE), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _belowId = uniV3Handler.tokenId(address(pool), _oor_belowLower, _oor_belowLower + pool.tickSpacing());
        uint256 _aboveId = uniV3Handler.tokenId(address(pool), _oor_aboveLower, _oor_aboveLower + pool.tickSpacing());

        assertEq(
            automator.getTickAllLiquidity(_oor_belowLower),
            uniV3Handler.convertToAssets(uint128(uniV3Handler.balanceOf(address(automator), _belowId)), _belowId),
            "below liquidity"
        );

        assertEq(
            automator.getTickAllLiquidity(_oor_aboveLower),
            uniV3Handler.convertToAssets(uint128(uniV3Handler.balanceOf(address(automator), _aboveId)), _aboveId),
            "above liquidity"
        );

        assertEq(automator.getTickAllLiquidity(-200000), 0, "tick no position");
    }

    function test_getTickFreeLiquidity() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDCE), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _belowId = uniV3Handler.tokenId(address(pool), _oor_belowLower, _oor_belowLower + pool.tickSpacing());
        uint256 _aboveId = uniV3Handler.tokenId(address(pool), _oor_aboveLower, _oor_aboveLower + pool.tickSpacing());

        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _belowInfo = _tokenInfo(_oor_belowLower);
        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _aboveInfo = _tokenInfo(_oor_aboveLower);

        emit log_named_uint("below total liquidity", _belowInfo.totalLiquidity);
        emit log_named_uint("below liquidity used", _belowInfo.liquidityUsed);
        emit log_named_uint("below free liquidity", _belowInfo.totalLiquidity - _belowInfo.liquidityUsed);

        emit log_named_uint("above total liquidity", _aboveInfo.totalLiquidity);
        emit log_named_uint("above liquidity used", _aboveInfo.liquidityUsed);
        emit log_named_uint("above free liquidity", _aboveInfo.totalLiquidity - _aboveInfo.liquidityUsed);

        _useDopexPosition(
            _oor_belowLower,
            _oor_belowLower + pool.tickSpacing(),
            _belowInfo.totalLiquidity - _belowInfo.liquidityUsed - 1000
        );

        assertEq(
            automator.getTickFreeLiquidity(_oor_belowLower),
            uniV3Handler.redeemableLiquidity(address(automator), _belowId),
            "below liquidity"
        );

        assertEq(
            automator.getTickFreeLiquidity(_oor_aboveLower),
            uniV3Handler.redeemableLiquidity(address(automator), _aboveId),
            "above liquidity"
        );

        assertEq(automator.getTickFreeLiquidity(-200000), 0, "tick no position");
    }

    function test_getActiveTicks() public {
        AutomatorHarness _automator = deployAutomatorHarness(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: uniV3Handler,
                router: router,
                pool: pool,
                asset: USDCE,
                minDepositAssets: 1e6,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoter: new ChainlinkQuoter()
            }),
            address(this),
            10_000e6
        );
        _automator.pushActiveTick(1);
        _automator.pushActiveTick(2);

        int24[] memory _actual = _automator.getActiveTicks();

        assertEq(_actual.length, 2);
        assertEq(_actual[0], 1);
        assertEq(_actual[1], 2);
    }
}
