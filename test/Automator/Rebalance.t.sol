// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "./Fixture.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {Automator} from "../../contracts/Automator.sol";
import {AutomatorUniswapV3PoolLib} from "../../contracts/lib/AutomatorUniswapV3PoolLib.sol";
import {IAutomator} from "../../contracts/interfaces/IAutomator.sol";

contract TestAutomatorRebalance is Fixture {
    using AutomatorUniswapV3PoolLib for IUniswapV3Pool;
    using FixedPointMathLib for uint256;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_rebalance_fromInitialState() public {
        deal(address(USDCE), address(automator), 10000e6);

        uint256 _balanceBasedUsdce = USDCE.balanceOf(address(automator));
        uint256 _balanceBasedWeth = _getQuote(address(USDCE), address(WETH), uint128(_balanceBasedUsdce));

        (int24 _oor_belowLower, ) = _outOfRangeBelow(1);
        (int24 _oor_aboveLower, ) = _outOfRangeAbove(1);

        /*///////////////////////////////////////////////////////////////////////////////////
                                    case: mint positions
        ///////////////////////////////////////////////////////////////////////////////////*/

        _mint(_balanceBasedUsdce, _balanceBasedWeth, _oor_belowLower, _oor_aboveLower);

        assertApproxEqRel(automator.totalAssets(), _balanceBasedWeth, 0.0005e18); // max 0.05% diff (swap fee)

        /*///////////////////////////////////////////////////////////////////////////////////
                                    case: burn & mint positions
        ///////////////////////////////////////////////////////////////////////////////////*/

        _burnAndMint(_balanceBasedUsdce, _oor_belowLower, _oor_aboveLower);

        assertApproxEqRel(automator.totalAssets(), _balanceBasedWeth, 0.0005e18); // max 0.05% diff (swap fee)
    }

    function test_calculateRebalanceSwapParamsInRebalance_reversedPair() public {
        _deployAutomator({
            admin: address(this),
            strategist: address(this),
            pool_: pool,
            asset: USDCE,
            minDepositAssets: 1e6,
            depositCap: 10_000e6
        });

        deal(address(USDCE), address(automator), 10000e6);

        // 10000e6 USDCE  = 4541342065417645174 WETH (currentTick: 199349)
        // liquidity(-199340, -199330) = 426528252665062768 (currentTick: -199349)

        IAutomator.RebalanceTickInfo[] memory _ticksMint = new Automator.RebalanceTickInfo[](1);
        IAutomator.RebalanceTickInfo[] memory _ticksBurn = new Automator.RebalanceTickInfo[](0);
        _ticksMint[0] = IAutomator.RebalanceTickInfo({tick: -199340, liquidity: 426528252665062768});

        IAutomator.RebalanceSwapParams memory _swapParams = automator.calculateRebalanceSwapParamsInRebalance(
            _ticksMint,
            _ticksBurn
        );

        assertApproxEqAbs(_swapParams.counterAssetsShortage, 4541342065417645174, 10);
        assertEq(_swapParams.maxAssetsUseForSwap, 10000e6);
        assertEq(_swapParams.assetsShortage, 0);
        assertEq(_swapParams.maxCounterAssetsUseForSwap, 0);
    }

    function test_onERC1155BatchReceived() public {
        assertEq(
            automator.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), ""),
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
        );
    }

    function test_checkMintValidity_false() public {
        _mockDopexHandlerTokenIdInfo(
            -199500,
            IUniswapV3SingleTickLiquidityHandler.TokenIdInfo({
                totalLiquidity: 0,
                totalSupply: 0,
                liquidityUsed: 0,
                feeGrowthInside0LastX128: 0,
                feeGrowthInside1LastX128: 0,
                tokensOwed0: 9,
                tokensOwed1: 9,
                lastDonation: 0,
                donatedLiquidity: 0,
                token0: address(USDCE),
                token1: address(WETH),
                fee: 3000
            })
        );

        assertEq(automator.checkMintValidity(-199500), false);
        vm.clearMockedCalls();
    }

    function test_checkMintValidity_true() public {
        _mockDopexHandlerTokenIdInfo(
            -199500,
            IUniswapV3SingleTickLiquidityHandler.TokenIdInfo({
                totalLiquidity: 0,
                totalSupply: 0,
                liquidityUsed: 0,
                feeGrowthInside0LastX128: 0,
                feeGrowthInside1LastX128: 0,
                tokensOwed0: 10,
                tokensOwed1: 10,
                lastDonation: 0,
                donatedLiquidity: 0,
                token0: address(USDCE),
                token1: address(WETH),
                fee: 3000
            })
        );

        assertEq(automator.checkMintValidity(-199500), true);
        vm.clearMockedCalls();
    }

    function _mockDopexHandlerTokenIdInfo(
        int24 lowerTick,
        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory ti
    ) internal {
        vm.mockCall(
            address(uniV3Handler),
            abi.encodeWithSelector(
                uniV3Handler.tokenIds.selector,
                uint256(keccak256(abi.encode(uniV3Handler, pool, lowerTick, lowerTick + pool.tickSpacing())))
            ),
            abi.encode(ti)
        );
    }

    function _mint(uint256 _amountUsdce, uint256 _amountWeth, int24 _oor_belowLower, int24 _oor_aboveLower) internal {
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

        (uint256 _a0, uint256 _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_belowLower),
            TickMath.getSqrtRatioAtTick(_oor_belowLower + pool.tickSpacing()),
            _ticksMint[0].liquidity
        );

        _ticksMint[1] = IAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: _toSingleTickLiquidity(
                _oor_aboveLower,
                (_amountWeth / 2) - (_amountWeth / 2).mulDivDown(pool.fee(), 1e6 - pool.fee()),
                0
            )
        });

        (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(pool.currentTick()),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower),
            TickMath.getSqrtRatioAtTick(_oor_aboveLower + pool.tickSpacing()),
            _ticksMint[1].liquidity
        );

        IAutomator.RebalanceTickInfo[] memory _ticksBurn = new IAutomator.RebalanceTickInfo[](0);

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            automator.calculateRebalanceSwapParamsInRebalance(_ticksMint, _ticksBurn)
        );
    }

    function _burnAndMint(uint256 _amountUsdce, int24 _oor_belowLower, int24 _oor_aboveLower) internal {
        IAutomator.RebalanceTickInfo[] memory _ticksMint = new IAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IAutomator.RebalanceTickInfo({
            tick: _oor_belowLower,
            liquidity: _toSingleTickLiquidity(
                _oor_belowLower,
                0,
                (_amountUsdce / 3) - (_amountUsdce / 3).mulDivDown(pool.fee(), 1e6 - pool.fee())
            )
        });

        IAutomator.RebalanceTickInfo[] memory _ticksBurn = new IAutomator.RebalanceTickInfo[](1);
        _ticksBurn[0] = IAutomator.RebalanceTickInfo({
            tick: _oor_aboveLower,
            liquidity: automator.getTickFreeLiquidity(_oor_belowLower)
        });

        automator.rebalance(
            _ticksMint,
            _ticksBurn,
            automator.calculateRebalanceSwapParamsInRebalance(_ticksMint, _ticksBurn)
        );
    }
}
