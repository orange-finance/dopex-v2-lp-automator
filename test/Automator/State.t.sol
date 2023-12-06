// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Fixture.sol";

contract TestAutomatorState is Fixture {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandler;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();
    }

    function test_totalAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDCE = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        deal(address(USDCE), address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDCE), address(WETH), uint128(_balanceUSDCE));

        emit log_named_uint("expected", _expected);

        assertEq(automator.totalAssets(), _expected);
    }

    function test_totalAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        deal(address(USDCE), address(automator), 1200e6);

        (, int24 _currentTick, , , , , ) = pool.slot0();

        emit log_named_int("current tick", _currentTick);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _oor_belowLowerInfo = _tokenInfo(_oor_belowLower);

        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);
        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _oor_aboveLowerInfo = _tokenInfo(_oor_aboveLower);

        emit log_string("========out of range below========");
        emit log_named_int("lower tick", _oor_belowLower);
        emit log_named_uint("total liquidity", _oor_belowLowerInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _oor_belowLowerInfo.liquidityUsed);

        emit log_string("========out of range above========");
        emit log_named_int("lower tick", _oor_aboveLower);
        emit log_named_uint("total liquidity", _oor_aboveLowerInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _oor_aboveLowerInfo.liquidityUsed);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

        Automator.MintParams[] memory _mintParams = new Automator.MintParams[](2);
        _mintParams[0] = Automator.MintParams({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });
        _mintParams[1] = Automator.MintParams({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(_mintParams, new Automator.BurnParams[](0));

        uint256 _assetsInAutomator = WETH.balanceOf(address(automator)) +
            _getQuote(address(USDCE), address(WETH), uint128(USDCE.balanceOf(address(automator))));

        emit log_named_uint("assets in automator", _assetsInAutomator);

        // allow bit of error because rounding will happen from different position => assets calculations
        assertApproxEqAbs(
            automator.totalAssets(),
            _assetsInAutomator +
                _positionToAssets(_oor_belowLower, address(automator)) +
                _positionToAssets(_oor_aboveLower, address(automator)),
            1
        );
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

        Automator.MintParams[] memory _mintParams = new Automator.MintParams[](2);
        _mintParams[0] = Automator.MintParams({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });

        _mintParams[1] = Automator.MintParams({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(_mintParams, new Automator.BurnParams[](0));

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

        Automator.MintParams[] memory _mintParams = new Automator.MintParams[](2);
        _mintParams[0] = Automator.MintParams({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                WETH.balanceOf(address(automator)) / 3,
                USDCE.balanceOf(address(automator)) / 3
            )
        });

        _mintParams[1] = Automator.MintParams({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                WETH.balanceOf(address(automator)) / 3,
                USDCE.balanceOf(address(automator)) / 3
            )
        });

        automator.rebalance(_mintParams, new Automator.BurnParams[](0));

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
}
