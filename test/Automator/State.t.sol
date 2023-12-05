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

        assertEq(automator.totalAssets(), _expected);
    }

    // function test_totalAssets_hasDopexPosition() public {
    //     uint256 _balanceWETH = 1.3 ether;
    //     uint256 _balanceUSDCE = 1200e6;

    //     deal(address(WETH), address(automator), _balanceWETH);
    //     deal(address(USDCE), address(automator), _balanceUSDCE);

    //     (, int24 _currentTick, , , , , ) = pool.slot0();
    //     int24 _spacing = pool.tickSpacing();

    //     emit log_named_int("current tick", _currentTick);

    //     int24 _oor_belowLower = _currentTick - (_currentTick % _spacing) - _spacing;
    //     uint256 _oor_belowLowerId = uniV3Handler.tokenId(address(pool), _oor_belowLower, _oor_belowLower + _spacing);
    //     IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _oor_belowLowerInfo = _tokenInfo(_oor_belowLower);

    //     int24 _oor_aboveLower = _currentTick - (_currentTick % _spacing) + _spacing;
    //     uint256 _oor_aboveLowerId = uniV3Handler.tokenId(address(pool), _oor_aboveLower, _oor_aboveLower + _spacing);
    //     IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _oor_aboveLowerInfo = _tokenInfo(_oor_aboveLower);

    //     emit log_string("========out of range below========");
    //     emit log_named_int("lower tick", _oor_belowLower);
    //     emit log_named_int("upper tick", _oor_belowLower + _spacing);
    //     emit log_named_uint("total liquidity", _oor_belowLowerInfo.totalLiquidity);
    //     emit log_named_uint("liquidity used", _oor_belowLowerInfo.liquidityUsed);

    //     emit log_string("========out of range above========");
    //     emit log_named_int("lower tick", _oor_aboveLower);
    //     emit log_named_int("upper tick", _oor_aboveLower + _spacing);
    //     emit log_named_uint("total liquidity", _oor_aboveLowerInfo.totalLiquidity);
    //     emit log_named_uint("liquidity used", _oor_aboveLowerInfo.liquidityUsed);

    //     uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
    //     uint256 _a1below = USDCE.balanceOf(address(automator)) / 3;

    //     uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
    //     uint256 _a1above = USDCE.balanceOf(address(automator)) / 3;

    //     _mintDopexPosition(
    //         _oor_belowLower,
    //         _oor_belowLower + _spacing,
    //         _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
    //     );

    //     _mintDopexPosition(
    //         _oor_aboveLower,
    //         _oor_aboveLower + _spacing,
    //         _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
    //     );

    //     uint256 _assetsInAutomator = WETH.balanceOf(address(automator)) +
    //         _getQuote(address(USDCE), address(WETH), uint128(USDCE.balanceOf(address(automator))));

    //     uint256 _sharesBelow = uniV3Handler.balanceOf(
    //         address(automator),
    //         uniV3Handler.tokenId(address(pool), _oor_belowLower, _oor_belowLower + _spacing)
    //     );
    //     uint256 _sharesAbove = uniV3Handler.balanceOf(
    //         address(automator),
    //         uniV3Handler.tokenId(address(pool), _oor_aboveLower, _oor_aboveLower + _spacing)
    //     );

    //     uint128 _liqBelow = uniV3Handler.convertToAssets(uint128(_sharesBelow), _oor_belowLowerId);
    //     uint128 _liqAbove = uniV3Handler.convertToAssets(uint128(_sharesAbove), _oor_aboveLowerId);
    // }
}
