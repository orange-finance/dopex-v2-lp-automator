// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, var-name-mixedcase, custom-errors, contract-name-camelcase */
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {IOrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/IOrangeStrykeLPAutomatorV1_1.sol";
import {IOrangeStrykeLPAutomatorState} from "./../../../contracts/interfaces/IOrangeStrykeLPAutomatorState.sol";
import {ChainlinkQuoter} from "../../../contracts/ChainlinkQuoter.sol";
import {UniswapV3SingleTickLiquidityLib} from "./../../../contracts/lib/UniswapV3SingleTickLiquidityLib.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {deployAutomatorHarness, DeployArgs, AutomatorHarness} from "./harness/AutomatorHarness.t.sol";
import {auto11} from "../../helper/AutomatorHelperV1_1.t.sol";
import {DealExtension} from "../../helper/DealExtension.t.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TestOrangeStrykeLPAutomatorV1_1State is WETH_USDC_Fixture, DealExtension {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;
    using TickMath for int24;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);
        super.setUp();
    }

    function test_totalAssets_noDopexPosition() public {
        uint256 _balanceWETH = 1.3 ether;
        uint256 _balanceUSDC = 1200e6;

        deal(address(WETH), address(automator), _balanceWETH);
        dealUsdc(address(automator), _balanceUSDC);

        uint256 _expected = _balanceWETH + _getQuote(address(USDC), address(WETH), uint128(_balanceUSDC));

        assertApproxEqRel(automator.totalAssets(), _expected, 0.0001e18);
    }

    function test_totalAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        dealUsdc(address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 3;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 3;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 3;

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });
        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _assetsInOrangeDopexV2LPAutomatorV1 = WETH.balanceOf(address(automator)) +
            _getQuote(address(USDC), address(WETH), uint128(USDC.balanceOf(address(automator))));

        emit log_named_uint("assets in automator", _assetsInOrangeDopexV2LPAutomatorV1);

        // allow bit of error because rounding will happen from different position => assets calculations
        // also error can happen from difference between the uniswap v3 pool price and chainlink price
        assertApproxEqRel(
            automator.totalAssets(),
            _assetsInOrangeDopexV2LPAutomatorV1 +
                _positionToAssets(_oor_belowLower, address(automator)) +
                _positionToAssets(_oor_aboveLower, address(automator)),
            0.0001e18
        );
    }

    function test_totalAssets_reversedPair() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeStrykeLPAutomatorV1_1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );
        dealUsdc(address(automator), 100e6);

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
        dealUsdc(address(automator), _usdceInVault);

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
        dealUsdc(address(automator), _usdceInVault);

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

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });

        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
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
        dealUsdc(address(automator), _balanceUSDCE);

        uint256 _expected = _balanceWETH + _getQuote(address(USDC), address(WETH), uint128(_balanceUSDCE));

        assertApproxEqRel(inspector.freeAssets(automator), _expected, 0.0001e18);
    }

    function test_freeAssets_hasDopexPositions() public {
        deal(address(WETH), address(automator), 1.3 ether);
        dealUsdc(address(automator), 1200e6);

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        uint256 _a0below = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1below = USDC.balanceOf(address(automator)) / 4;

        uint256 _a0above = WETH.balanceOf(address(automator)) / 4;
        uint256 _a1above = USDC.balanceOf(address(automator)) / 4;

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(_oor_belowLower, _a0below, _a1below)
        });
        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(_oor_aboveLower, _a0above, _a1above)
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
        );

        uint256 _assetsInOrangeDopexV2LPAutomatorV1 = WETH.balanceOf(address(automator)) +
            _getQuote(address(USDC), address(WETH), uint128(USDC.balanceOf(address(automator))));
        uint256 _freeAssets = _assetsInOrangeDopexV2LPAutomatorV1 +
            _positionToAssets(_oor_belowLower, address(automator)) +
            _positionToAssets(_oor_aboveLower, address(automator));

        assertApproxEqRel(inspector.freeAssets(automator), _freeAssets, 0.0001e18);
    }

    function test_freeAssets_reversedPair() public {
        automator = auto11.deploy(
            auto11.DeployArgs({
                name: "OrangeStrykeLPAutomatorV1_1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                strategist: address(this),
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                manager: manager,
                router: router,
                handler: handlerV2,
                handlerHook: address(0),
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                depositCap: 10_000e6
            })
        );

        dealUsdc(address(automator), 100e6);

        assertApproxEqRel(inspector.freeAssets(automator), 100e6, 0.0001e18);
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
        dealUsdc(address(automator), _usdceInVault);

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
        dealUsdc(address(automator), _usdceInVault);

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

        IOrangeStrykeLPAutomatorState.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](2);
        _ticksMint[0] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                WETH.balanceOf(address(automator)) / 3,
                USDC.balanceOf(address(automator)) / 3
            )
        });

        _ticksMint[1] = IOrangeStrykeLPAutomatorState.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                WETH.balanceOf(address(automator)) / 3,
                USDC.balanceOf(address(automator)) / 3
            )
        });

        automator.rebalance(
            _ticksMint,
            new IOrangeStrykeLPAutomatorState.RebalanceTickInfo[](0),
            IOrangeStrykeLPAutomatorV1_1.RebalanceSwapParams(0, 0, 0, 0)
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

    function test_getActiveTicks() public {
        AutomatorHarness _automator = deployAutomatorHarness(
            DeployArgs({
                name: "OrangeStrykeLPAutomatorV1_1",
                symbol: "ODV2LP",
                dopexV2ManagerOwner: managerOwner,
                admin: address(this),
                assetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                counterAssetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoter: chainlinkQuoter,
                manager: manager,
                handler: handlerV2,
                handlerHook: address(0),
                router: router,
                pool: pool,
                asset: USDC,
                minDepositAssets: 1e6,
                strategist: address(this),
                depositCap: 10_000e6
            })
        );
        _automator.pushActiveTick(1);
        _automator.pushActiveTick(2);

        int24[] memory _actual = _automator.getActiveTicks();

        assertEq(_actual.length, 2);
        assertEq(_actual[0], 1);
        assertEq(_actual[1], 2);
    }

    function _liquidity0(int24 tickLower, uint256 amount0) private pure returns (uint128) {
        uint128 lq = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickLower + 10),
            amount0
        );

        if (lq == 0) revert("invalid liquidity input");

        return lq;
    }

    function _liquidity1(int24 tickLower, uint256 amount1) private pure returns (uint128) {
        uint128 lq = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickLower + 10),
            amount1
        );

        if (lq == 0) revert("invalid liquidity input");

        return lq;
    }

    function _outOfRangeBelow(int24 mulOffset) internal view returns (int24 tick, uint256 tokenId) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        tick = _currentTick - (_currentTick % _spacing) - _spacing * (mulOffset + 1);
        tokenId = handlerV2.tokenId(address(pool), address(0), tick, tick + _spacing);
    }

    function _outOfRangeAbove(int24 mulOffset) internal view returns (int24 tick, uint256 tokenId) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        tick = _currentTick - (_currentTick % _spacing) + _spacing * mulOffset;
        tokenId = handlerV2.tokenId(address(pool), address(0), tick, tick + _spacing);
    }

    function _getQuote(address base, address quote, uint128 baseAmount) internal view returns (uint256) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(_currentTick, baseAmount, base, quote);
    }

    function _toSingleTickLiquidity(int24 lower, uint256 amount0, uint256 amount1) internal view returns (uint128) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                _currentTick.getSqrtRatioAtTick(),
                lower.getSqrtRatioAtTick(),
                (lower + pool.tickSpacing()).getSqrtRatioAtTick(),
                amount0,
                amount1
            );
    }

    function _positionToAssets(int24 lowerTick, address account) internal view returns (uint256) {
        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), lowerTick, lowerTick + pool.tickSpacing());
        uint128 _liquidity = handlerV2.convertToAssets(uint128(handlerV2.balanceOf(account, _tokenId)), _tokenId);

        (uint160 _sqrtPriceX96, , , , , , ) = pool.slot0();

        (uint256 _amount0, uint256 _amount1) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            lowerTick.getSqrtRatioAtTick(),
            (lowerTick + pool.tickSpacing()).getSqrtRatioAtTick(),
            _liquidity
        );

        IERC20 _baseAsset = pool.token0() == address(automator.asset()) ? IERC20(pool.token1()) : IERC20(pool.token0());
        IERC20 _quoteAsset = pool.token0() == address(automator.asset())
            ? IERC20(pool.token0())
            : IERC20(pool.token1());

        uint256 _base = pool.token0() == address(automator.asset()) ? _amount1 : _amount0;
        uint256 _quote = pool.token0() == address(automator.asset()) ? _amount0 : _amount1;

        return _quote + _getQuote(address(_baseAsset), address(_quoteAsset), uint128(_base));
    }

    function _tokenInfo(int24 lower) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory) {
        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), lower, lower + pool.tickSpacing());
        return handlerV2.tokenIds(_tokenId);
    }

    function _useDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidityToUse) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.UsePositionParams memory _params = IUniswapV3SingleTickLiquidityHandlerV2
            .UsePositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: lowerTick,
                tickUpper: upperTick,
                liquidityToUse: liquidityToUse
            });

        manager.usePosition(handlerV2, abi.encode(_params, ""));
    }
}
