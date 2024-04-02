// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, custom-errors */
import {WETH_USDC_Fixture} from "test/OrangeDopexV2LPAutomator/v2/fixture/WETH_USDC_Fixture.t.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "contracts/lib/UniswapV3SingleTickLiquidityLibV2.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3Helper} from "test/helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "test/helper/DopexV2Helper.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract TestUniswapV3SingleTickLiquidityLibV2 is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 196444430);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
    }

    function test_tokenId() public view {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        uint256 _tokenId = UniswapV3SingleTickLiquidityLibV2.tokenId(
            handlerV2,
            address(pool),
            address(0),
            _currentTick,
            _currentTick + _spacing
        );
        assertEq(
            _tokenId,
            uint256(keccak256(abi.encode(handlerV2, address(pool), address(0), _currentTick, _currentTick + _spacing)))
        );
    }

    function test_redeemableLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 cl = pool.currentLower();

        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        pool.mintDopexPosition(address(0), cl - 20, pool.singleLiqLeft(cl - 20, 100_000e6), address(this));
        (, uint128 redeemable, ) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        assertApproxEqRel(redeemable, pool.singleLiqLeft(cl - 20, 100_000e6), 0.0001e18);

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, pool.freeLiquidityOfTick(address(0), cl - 20) - 1000e6);
        (, redeemable, ) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        assertEq(redeemable, 1000e6, "partial liquidity redeemable");

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, 1000e6);
        (, redeemable, ) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        assertEq(redeemable, 0, "no liquidity redeemable");
    }

    function test_redeemableLiquidity_shouldNotUnderflow() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 cl = pool.currentLower();

        pool.mintDopexPosition(address(0), cl - 20, pool.singleLiqLeft(cl - 20, 100_000e6), address(this));

        uint128 _twoThirdOfFreeLiquidity = (pool.freeLiquidityOfTick(address(0), cl - 20) * 2) / 3;
        // use two-third of the liquidity
        pool.useDopexPosition(address(0), cl - 20, _twoThirdOfFreeLiquidity);

        // reserve same amount of liquidity
        // then totalLiquidity < liquidityUsed = reservedLiquidity
        pool.reserveDopexPosition(address(0), cl - 20, _twoThirdOfFreeLiquidity, address(this));

        (, uint128 _redeemable, ) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        // redeemable liquidity (totalLiquidity - liquidityUsed) should not underflow. It should be 0
        assertEq(0, _redeemable);
    }

    function test_lockedLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 cl = pool.currentLower();
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        pool.mintDopexPosition(address(0), cl - 20, pool.singleLiqLeft(cl - 20, 100_000e6), address(this));
        (, , uint128 _locked) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );
        //
        assertEq(_locked, 0, "no liquidity locked");

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, pool.freeLiquidityOfTick(address(0), cl - 20) - 1000e6);
        (, , _locked) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        assertApproxEqRel(
            _locked,
            handlerV2.convertToAssets(
                uint128(handlerV2.balanceOf(address(this), pool.tokenId(address(0), cl - 20))),
                pool.tokenId(address(0), cl - 20)
            ) - 1000e6,
            0.0001e18
        );

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, 1000e6);
        (, , _locked) = UniswapV3SingleTickLiquidityLibV2.positionDetail(
            handlerV2,
            address(this),
            pool.tokenId(address(0), cl - 20)
        );

        assertApproxEqRel(
            _locked,
            handlerV2.convertToAssets(
                uint128(handlerV2.balanceOf(address(this), pool.tokenId(address(0), cl - 20))),
                pool.tokenId(address(0), cl - 20)
            ),
            0.0001e18
        );
    }

    function test_lockedLiquidity_shouldNotUnderflow() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 cl = pool.currentLower();

        pool.mintDopexPosition(address(0), cl - 10, pool.singleLiqLeft(cl - 10, 100_000e6), address(this));

        uint128 _twoThirdOfFreeLiquidity = (pool.freeLiquidityOfTick(address(0), cl - 10) * 2) / 3;
        // use two-third of the liquidity
        pool.useDopexPosition(address(0), cl - 10, _twoThirdOfFreeLiquidity);

        // reserve same amount of liquidity
        pool.reserveDopexPosition(address(0), cl - 10, _twoThirdOfFreeLiquidity, address(this));

        uint256 _tokenId = pool.tokenId(address(0), cl - 10);
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _ti = handlerV2.tokenIds(_tokenId);

        // then totalLiquidity < liquidityUsed = reservedLiquidity
        assertLt(_ti.totalLiquidity, _ti.liquidityUsed);

        // locked liquidity calculation should not underflow.
        uint256 _expectLocked = handlerV2.convertToAssets(
            uint128(handlerV2.balanceOf(address(this), _tokenId)),
            _tokenId
        );

        (, , uint128 _locked) = UniswapV3SingleTickLiquidityLibV2.positionDetail(handlerV2, address(this), _tokenId);

        assertEq(_expectLocked, _locked);
    }
}
