// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Fixture.t.sol";
import {IOrangeDopexV2LPAutomator} from "../../contracts/interfaces/IOrangeDopexV2LPAutomator.sol";
import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";
import {deployAutomatorHarness, AutomatorHarness} from "./harness/AutomatorHarness.t.sol";
import {AutomatorHelper} from "../helper/AutomatorHelper.t.sol";

contract TestOrangeDopexV2LPAutomatorState is Fixture {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;

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
        deal(address(USDC), address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDC), address(WETH), uint128(_balanceUSDCE));

        assertApproxEqRel(automator.totalAssets(), _expected, 0.0001e18);
    }

    function test_totalAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDC), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 3;

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
            _getQuote(address(USDC), address(WETH), uint128(USDC.balanceOf(address(automator))));

        emit log_named_uint("assets in automator", _assetsInOrangeDopexV2LPAutomator);

        // allow bit of error because rounding will happen from different position => assets calculations
        // also error can happen from difference between the uniswap v3 pool price and chainlink price
        assertApproxEqRel(
            automator.totalAssets(),
            _assetsInOrangeDopexV2LPAutomator +
                _positionToAssets(_oor_belowLower, address(automator)) +
                _positionToAssets(_oor_aboveLower, address(automator)),
            0.0001e18
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
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                handlerHook: emptyHook,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        deal(address(USDC), address(automator), 100e6);

        assertApproxEqRel(automator.totalAssets(), 100e6, 0.0001e18);
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

        assertApproxEqRel(
            automator.convertToAssets(_aliceShares),
            _aliceDeposit - automator.convertToAssets(_deadInFirstDeposit),
            0.0001e18
        );

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDC), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDC), address(WETH), uint128(_usdceInVault));

        assertApproxEqRel(automator.convertToAssets(_aliceShares), _aliceAssets, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);

        assertApproxEqRel(automator.convertToAssets(_bobShares), _bobDeposit, 0.0001e18);
        assertApproxEqRel(automator.convertToAssets(_aliceShares), _aliceAssets, 0.0001e18);
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

        assertApproxEqRel(
            automator.convertToAssets(_aliceShares),
            _aliceDeposit - automator.convertToAssets(_deadInFirstDeposit),
            0.0001e18
        );

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDC), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDC), address(WETH), uint128(_usdceInVault));

        assertApproxEqRel(automator.convertToAssets(_aliceShares), _aliceAssets, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqRel(automator.convertToAssets(_bobShares), _bobDeposit, 0.0001e18);
        assertApproxEqRel(automator.convertToAssets(_aliceShares), _aliceAssets, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: dopex position minted
        ///////////////////////////////////////////////////////*/

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 3;

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

        assertApproxEqRel(
            automator.convertToAssets(_aliceShares),
            (_aliceShares * automator.totalAssets()) / automator.totalSupply(),
            0.0001e18
        );

        assertApproxEqRel(
            automator.convertToAssets(_bobShares),
            (_bobShares * automator.totalAssets()) / automator.totalSupply(),
            0.0001e18
        );
    }

    function test_freeAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDCE = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        deal(address(USDC), address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDC), address(WETH), uint128(_balanceUSDCE));

        assertApproxEqRel(automator.freeAssets(), _expected, 0.0001e18);
    }

    function test_freeAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDC), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 4;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 4;

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
            _getQuote(address(USDC), address(WETH), uint128(USDC.balanceOf(address(automator))));
        uint256 _freeAssets = _assetsInOrangeDopexV2LPAutomator +
            _positionToAssets(_oor_belowLower, address(automator)) +
            _positionToAssets(_oor_aboveLower, address(automator));

        assertApproxEqRel(automator.freeAssets(), _freeAssets, 0.0001e18);
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
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: uniV3Handler,
                handlerHook: emptyHook,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        deal(address(USDC), address(automator), 100e6);

        assertApproxEqRel(automator.freeAssets(), 100e6, 0.0001e18);
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

        assertApproxEqRel(automator.convertToShares(1.3 ether), _aliceShares + _deadInFirstDeposit, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDC), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDC), address(WETH), uint128(_usdceInVault));

        assertApproxEqRel(automator.convertToShares(_aliceAssets), _aliceShares, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqRel(automator.convertToShares(_bobDeposit), _bobShares, 0.0001e18);
        assertApproxEqRel(automator.convertToShares(_aliceAssets), _aliceShares, 0.0001e18);
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

        assertApproxEqRel(automator.convertToShares(1.3 ether), _aliceShares + _deadInFirstDeposit, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 1 depositor (pair token)
        ///////////////////////////////////////////////////////*/
        uint256 _usdceInVault = 1200e6;
        deal(address(USDC), address(automator), _usdceInVault);

        uint256 _aliceAssets = _aliceDeposit -
            automator.convertToAssets(_deadInFirstDeposit) +
            _getQuote(address(USDC), address(WETH), uint128(_usdceInVault));

        assertApproxEqRel(automator.convertToShares(_aliceAssets), _aliceShares, 0.0001e18);

        /*///////////////////////////////////////////////////////
                        case: 2 depositors (pair token)
        ///////////////////////////////////////////////////////*/

        uint256 _bobDeposit = 1 ether;
        deal(address(WETH), bob, _bobDeposit);

        vm.startPrank(bob);
        WETH.approve(address(automator), type(uint256).max);
        uint256 _bobShares = automator.deposit(_bobDeposit);
        vm.stopPrank();

        assertApproxEqRel(automator.convertToShares(_bobDeposit), _bobShares, 0.0001e18);
        assertApproxEqRel(automator.convertToShares(_aliceAssets), _aliceShares, 0.0001e18);

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
                USDC.balanceOf(address(automator)) / 3
            )
        });

        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                WETH.balanceOf(address(automator)) / 3,
                USDC.balanceOf(address(automator)) / 3
            )
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );

        assertApproxEqRel(
            automator.convertToShares((_aliceShares * automator.totalAssets()) / automator.totalSupply()),
            _aliceShares,
            0.0001e18
        );

        assertApproxEqRel(
            automator.convertToShares((_bobShares * automator.totalAssets()) / automator.totalSupply()),
            _bobShares,
            0.0001e18
        );
    }

    function test_getTickAllLiquidity() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDC), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 3;

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

        uint256 _belowId = uniV3Handler.tokenId(
            address(pool),
            emptyHook,
            _oor_belowLower,
            _oor_belowLower + pool.tickSpacing()
        );
        uint256 _aboveId = uniV3Handler.tokenId(
            address(pool),
            emptyHook,
            _oor_aboveLower,
            _oor_aboveLower + pool.tickSpacing()
        );

        assertApproxEqRel(
            automator.getTickAllLiquidity(_oor_belowLower),
            uniV3Handler.convertToAssets(uint128(uniV3Handler.balanceOf(address(automator), _belowId)), _belowId),
            0.0001e18
        );

        assertApproxEqRel(
            automator.getTickAllLiquidity(_oor_aboveLower),
            uniV3Handler.convertToAssets(uint128(uniV3Handler.balanceOf(address(automator), _aboveId)), _aboveId),
            0.0001e18
        );

        assertApproxEqRel(automator.getTickAllLiquidity(-200000), 0, 0.0001e18);
    }

    function test_getTickFreeLiquidity() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDC), address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 3;

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

        uint256 _belowId = uniV3Handler.tokenId(
            address(pool),
            emptyHook,
            _oor_belowLower,
            _oor_belowLower + pool.tickSpacing()
        );
        uint256 _aboveId = uniV3Handler.tokenId(
            address(pool),
            emptyHook,
            _oor_aboveLower,
            _oor_aboveLower + pool.tickSpacing()
        );

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _belowInfo = _tokenInfo(_oor_belowLower);
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _aboveInfo = _tokenInfo(_oor_aboveLower);

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

        assertApproxEqRel(
            automator.getTickFreeLiquidity(_oor_belowLower),
            uniV3Handler.redeemableLiquidity(address(automator), _belowId),
            0.0001e18
        );

        assertApproxEqRel(
            automator.getTickFreeLiquidity(_oor_aboveLower),
            uniV3Handler.redeemableLiquidity(address(automator), _aboveId),
            0.0001e18
        );

        assertApproxEqRel(automator.getTickFreeLiquidity(-200000), 0, 0.0001e18);
    }

    function test_getActiveTicks() public {
        AutomatorHarness _automator = deployAutomatorHarness(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: uniV3Handler,
                handlerHook: emptyHook,
                router: router,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D))
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

    function test_getAutomatorPositions() public {
        OrangeDopexV2LPAutomator _automator = AutomatorHelper.deployOrangeDopexV2LPAutomator(
            vm,
            AutomatorHelper.DeployArgs({
                name: "odpx-WETH-USDC",
                symbol: "odpx-WETH-USDC",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                manager: manager,
                handler: uniV3Handler,
                handlerHook: emptyHook,
                router: router,
                pool: pool,
                asset: WETH,
                minDepositAssets: 0.01 ether,
                depositCap: 1000 ether,
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
            })
        );

        deal(address(WETH), address(_automator), 100 ether);
        deal(address(USDC), address(_automator), 100_000e6);

        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](2);
        // mint liquidity use 50k USDC at -199360
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: -199360, liquidity: 2131788420041464685});
        // mint liquidity use 50 WETH at -199340
        _ticksMint[1] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: -199340, liquidity: 4696059518540551032});

        AutomatorHelper.rebalanceMint(_automator, _ticksMint);

        (
            uint256 _balAsset,
            uint256 _balCounterAsset,
            IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory _ticks
        ) = _automator.getAutomatorPositions();

        assertApproxEqAbs(_balAsset, 50 ether, 10);
        assertApproxEqAbs(_balCounterAsset, 50_000e6, 10);

        assertEq(_ticks.length, 2);

        assertEq(_ticks[0].tick, -199360);
        assertApproxEqRel(_ticks[0].liquidity, 2131788420041464685, 0.00001e18); // 0.001% tolerance
        assertEq(_ticks[1].tick, -199340);
        assertApproxEqRel(_ticks[1].liquidity, 4696059518540551032, 0.00001e18); // 0.001% tolerance
    }
}
