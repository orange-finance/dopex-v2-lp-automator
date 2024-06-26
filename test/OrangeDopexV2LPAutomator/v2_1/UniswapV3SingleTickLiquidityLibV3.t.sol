// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, custom-errors */
import {WETH_USDC_Fixture} from "test/OrangeDopexV2LPAutomator/v2/fixture/WETH_USDC_Fixture.t.sol";
import {UniswapV3SingleTickLiquidityLibV3} from "contracts/lib/UniswapV3SingleTickLiquidityLibV3.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3Helper} from "test/helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "test/helper/DopexV2Helper.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestUniswapV3SingleTickLiquidityLibV3 is WETH_USDC_Fixture {
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

        uint256 _tokenId = UniswapV3SingleTickLiquidityLibV3.tokenId(
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
        (, uint128 redeemable, , , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        assertApproxEqRel(redeemable, pool.singleLiqLeft(cl - 20, 100_000e6), 0.0001e18);

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, pool.freeLiquidityOfTick(address(0), cl - 20) - 1000e6);
        (, redeemable, , , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        assertEq(redeemable, 1000e6, "partial liquidity redeemable");

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, 1000e6);
        (, redeemable, , , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
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

        (, uint128 redeemable, , , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        // redeemable liquidity (totalLiquidity - liquidityUsed) should not underflow. It should be 0
        assertEq(0, redeemable);
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
        (, , uint128 locked, , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        assertEq(locked, 0, "no liquidity locked");

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        pool.useDopexPosition(address(0), cl - 20, pool.freeLiquidityOfTick(address(0), cl - 20) - 1000e6);
        (, , locked, , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        assertApproxEqRel(
            locked,
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
        (, , locked, , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 20,
                tickUpper: cl - 10,
                owner: address(this)
            })
        );

        assertApproxEqRel(
            locked,
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

        (, , uint128 locked, , ) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 10,
                tickUpper: cl,
                owner: address(this)
            })
        );

        assertEq(_expectLocked, locked);
    }

    function test_positionDetail_reflectSwapFee0() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 10_000_000e6);

        int24 cl = pool.currentLower();

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);
        pool.mintDopexPosition(address(0), cl + 10, pool.singleLiqRight(cl + 10, 1000 ether), address(this));

        (, , , uint256 swapFee0Before, uint256 swapFee1Before) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl + 10,
                tickUpper: cl + 20,
                owner: address(this)
            })
        );

        _swap(USDC, WETH, 5_000_000e6);

        // burn little bit to reflect swap fee
        pool.burnDopexPosition(address(0), cl + 10, 1, address(this));

        (, , , uint256 swapFee0After, uint256 swapFee1After) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl + 10,
                tickUpper: cl + 20,
                owner: address(this)
            })
        );

        assertGt(swapFee1After, swapFee1Before, "swap fee 1 should increase");
        assertEq(swapFee0After, swapFee0Before, "swap fee 0 should not change");
    }

    function test_positionDetail_reflectSwapFee1() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDC), address(this), 1_000_000e6);

        int24 cl = pool.currentLower();

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);
        pool.mintDopexPosition(address(0), cl - 10, pool.singleLiqLeft(cl - 10, 100_000e6), address(this));

        (, , , uint256 swapFee0Before, uint256 swapFee1Before) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 10,
                tickUpper: cl,
                owner: address(this)
            })
        );

        _swap(WETH, USDC, 1000 ether);

        // burn little bit to reflect swap fee
        pool.burnDopexPosition(address(0), cl - 10, 1, address(this));

        (, , , uint256 swapFee0After, uint256 swapFee1After) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
            UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                handler: handlerV2,
                pool: address(pool),
                hook: address(0),
                tickLower: cl - 10,
                tickUpper: cl,
                owner: address(this)
            })
        );

        // swap fee is reflected in tokenOwed0
        assertGt(swapFee0After, swapFee0Before, "swap fee 0 should increase");
        assertEq(swapFee1After, swapFee1Before, "swap fee 1 should not change");
    }

    function _swap(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn) internal {
        tokenIn.approve(address(router), type(uint256).max);
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(tokenIn),
                tokenOut: address(tokenOut),
                fee: pool.fee(),
                recipient: address(this),
                deadline: type(uint256).max,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
