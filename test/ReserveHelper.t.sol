// SPDX-License-Identifier: GPL-3.0

/* solhint-disable one-contract-per-file, func-name-mixedcase, avoid-low-level-calls, custom-errors */

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {INIT_FACTORY, INIT_UNISWAP_ROUTER, INIT_POSITION_MANAGER, INIT_UNI_HANDLER_V2} from "./creationCodes.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {IDopexV2PositionManager} from "../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";

import {ReserveHelper} from "../contracts/periphery/reserve-liquidity/ReserveHelper.sol";
import {ReserveProxy} from "../contracts/periphery/reserve-liquidity/ReserveProxy.sol";

import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

import {IERC6909} from "../contracts/vendor/dopexV2/IERC6909.sol";

abstract contract Base is Test {
    MockERC20 public mock0 = MockERC20(address(0x10));
    MockERC20 public mock1 = MockERC20(address(0x20));
    // not used in test. so make uninitialized
    address public weth9 = address(0);

    IUniswapV3Pool public pool;
    IUniswapV3Factory public factory;
    ISwapRouter public router;

    IDopexV2PositionManager public manager;
    IUniswapV3SingleTickLiquidityHandlerV2 public handlerV2;

    function initialize(uint8 t0decimals, uint8 t1decimals, uint24 poolFee, uint160 sqrtPriceX96) public virtual {
        vm.etch(address(mock0), address(deployMockERC20("Mock0", "MC0", t0decimals)).code);
        vm.etch(address(mock1), address(deployMockERC20("Mock1", "MC1", t1decimals)).code);
        factory = deployFactory();
        router = deploySwapRouter(address(factory), address(weth9));
        pool = deployV3Pool(address(mock0), address(mock1), poolFee, sqrtPriceX96);
        manager = deployPositionManager();
        handlerV2 = deployUniHandlerV2(address(factory), address(router));

        vm.label(address(factory), "factory");
        vm.label(address(router), "router");
        vm.label(address(pool), "pool");
        vm.label(address(manager), "manager");
        vm.label(address(handlerV2), "handlerV2");
    }

    function deployFactory() internal returns (IUniswapV3Factory factory_) {
        bytes memory code = INIT_FACTORY;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            factory_ := create(0, add(code, 0x20), mload(code))
        }
    }

    function deploySwapRouter(address factory_, address weth9_) internal returns (ISwapRouter router_) {
        bytes memory args = abi.encode(factory_, weth9_);
        bytes memory code = abi.encodePacked(INIT_UNISWAP_ROUTER, args);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            router_ := create(0, add(code, 0x20), mload(code))
        }
    }

    function deployV3Pool(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) internal returns (IUniswapV3Pool pool_) {
        if (token0 >= token1) (token0, token1) = (token1, token0);

        pool_ = IUniswapV3Pool(factory.createPool(token0, token1, fee));
        pool_.initialize(sqrtPriceX96);
    }

    function deployPositionManager() internal returns (IDopexV2PositionManager manager_) {
        bytes memory code = INIT_POSITION_MANAGER;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            manager_ := create(0, add(code, 0x20), mload(code))

            if iszero(manager_) {
                revert(0, 0)
            }
        }
    }

    function deployUniHandlerV2(
        address factory_,
        address swapRouter
    ) internal returns (IUniswapV3SingleTickLiquidityHandlerV2 handler_) {
        bytes memory code = abi.encodePacked(
            INIT_UNI_HANDLER_V2,
            abi.encode(factory_, PoolAddress.POOL_INIT_CODE_HASH, swapRouter)
        );
        // solhint-disable-next-line no-inline-assembly
        assembly {
            handler_ := create(0, add(code, 0x20), mload(code))

            if iszero(handler_) {
                revert(0, 0)
            }
        }
    }

    function _mintRightPosition(address to, int24 tickLower, int24 tickUpper, uint256 token0) internal {
        mock0.approve(address(handlerV2), token0);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0
        );
        _mintPosition(to, tickLower, tickUpper, liquidity);
    }

    function _mintLeftPosition(address to, int24 tickLower, int24 tickUpper, uint256 token1) internal {
        mock1.approve(address(handlerV2), token1);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token1
        );
        _mintPosition(to, tickLower, tickUpper, liquidity);
    }

    function _mintPosition(address to, int24 tickLower, int24 tickUpper, uint128 liquidity) internal {
        bytes memory mint = abi.encode(
            IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity
            })
        );

        handlerV2.mintPositionHandler(to, mint);
    }

    function _useRightPosition(address useFor, int24 tickLower, int24 tickUpper, uint256 token0) internal {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0
        );
        _usePosition(useFor, tickLower, tickUpper, liquidity);
    }

    function _useLeftPosition(address useFor, int24 tickLower, int24 tickUpper, uint256 token1) internal {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token1
        );
        _usePosition(useFor, tickLower, tickUpper, liquidity);
    }

    function _usePosition(address useFor, int24 tickLower, int24 tickUpper, uint128 liquidity) internal {
        bool whitelisted = handlerV2.whitelistedApps(useFor);
        if (!whitelisted) {
            handlerV2.updateWhitelistedApps(useFor, true);
        }
        bytes memory use = abi.encode(
            IUniswapV3SingleTickLiquidityHandlerV2.UsePositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityToUse: liquidity
            }),
            ""
        );

        vm.prank(useFor);
        handlerV2.usePositionHandler(use);
    }

    function _unuseRightPosition(address unuseFor, int24 tickLower, int24 tickUpper, uint256 token0) internal {
        vm.prank(unuseFor);
        mock0.approve(address(handlerV2), token0);
        uint128 liquidity = liquidity0(token0, tickLower, tickUpper);
        _unusePosition(unuseFor, tickLower, tickUpper, liquidity);
    }

    function _unuseLeftPosition(address unuseFor, int24 tickLower, int24 tickUpper, uint256 token1) internal {
        vm.prank(unuseFor);
        mock1.approve(address(handlerV2), token1);
        uint128 liquidity = liquidity1(token1, tickLower, tickUpper);
        _unusePosition(unuseFor, tickLower, tickUpper, liquidity);
    }

    function _unusePosition(address unuseFor, int24 tickLower, int24 tickUpper, uint128 liquidity) internal {
        bool whitelisted = handlerV2.whitelistedApps(unuseFor);
        if (!whitelisted) {
            handlerV2.updateWhitelistedApps(unuseFor, true);
        }
        bytes memory unuse = abi.encode(
            IUniswapV3SingleTickLiquidityHandlerV2.UnusePositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityToUnuse: liquidity
            }),
            ""
        );

        vm.prank(unuseFor);
        handlerV2.unusePositionHandler(unuse);
    }

    function _burnParamsRight(
        address pool_,
        int24 tickLower,
        int24 tickUpper,
        uint256 token0
    ) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory) {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0
        );

        uint256 tokenId = uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)));

        uint128 shares = handlerV2.convertToShares(liquidity, tokenId);

        return
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                pool: pool_,
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: shares
            });
    }

    function _burnParamsLeft(
        address pool_,
        int24 tickLower,
        int24 tickUpper,
        uint256 token1
    ) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams memory) {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token1
        );

        uint256 tokenId = uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)));

        uint128 shares = handlerV2.convertToShares(liquidity, tokenId);

        return
            IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                pool: pool_,
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: shares
            });
    }

    function liquidity0(uint256 token0, int24 tickLower, int24 tickUpper) internal pure returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmount0(
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                token0
            );
    }

    function liquidity1(uint256 token1, int24 tickLower, int24 tickUpper) internal pure returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmount1(
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                token1
            );
    }
}

contract TestReserveHelper is Base {
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public carol = makeAddr("Carol");

    address[] public accounts = [alice, bob, carol];

    ReserveProxy public reserveProxy;

    function setUp() public {
        // initialize current tick to zero
        initialize(18, 6, 500, 0.7923e29);

        (bool success, ) = address(handlerV2).call(
            abi.encodeWithSignature("updateWhitelistedApps(address,bool)", address(this), true)
        );
        assertTrue(success, "updateWhitelistedApps failed");
        reserveProxy = new ReserveProxy();
    }

    function test_batchReserveLiquidity() public {
        deal(address(mock0), address(this), 10e18);
        deal(address(mock1), address(this), 100e6);

        _mintRightPosition(alice, 10, 20, 5e18);
        _mintRightPosition(alice, 20, 30, 5e18);
        _mintLeftPosition(alice, -30, -20, 50e6);
        _mintLeftPosition(alice, -20, -10, 50e6);
        _useRightPosition(bob, 10, 20, 4e18);
        _useRightPosition(bob, 20, 30, 4e18);
        _useLeftPosition(bob, -30, -20, 40e6);
        _useLeftPosition(bob, -20, -10, 40e6);

        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[]
            memory reserveParams = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](4);

        reserveParams[0] = _burnParamsRight(address(pool), 10, 20, 4e18);
        reserveParams[1] = _burnParamsRight(address(pool), 20, 30, 4e18);
        reserveParams[2] = _burnParamsLeft(address(pool), -30, -20, 40e6);
        reserveParams[3] = _burnParamsLeft(address(pool), -20, -10, 40e6);

        _batchReserveLiquidity(alice, reserveParams);

        assertEq(reservedLiquidity(alice, address(pool), 10, 20), liquidity0(4e18, 10, 20), "liquidity reserved tick(10,20)"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), 20, 30), liquidity0(4e18, 20, 30), "liquidity reserved tick(20,30)"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), -30, -20), liquidity1(40e6, -30, -20), "liquidity reserved tick(-30,-20)"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), -20, -10), liquidity1(40e6, -20, -10), "liquidity reserved tick(-20,-10)"); // prettier-ignore
    }

    function test_batchWithdrawReserveLiquidity() public {
        deal(address(mock0), address(this), 10e18);
        deal(address(mock1), address(this), 100e6);

        _mintRightPosition(alice, 10, 20, 5e18);
        _mintRightPosition(alice, 20, 30, 5e18);
        _mintLeftPosition(alice, -30, -20, 50e6);
        _mintLeftPosition(alice, -20, -10, 50e6);
        _useRightPosition(bob, 10, 20, 4e18);
        _useRightPosition(bob, 20, 30, 4e18);
        _useLeftPosition(bob, -30, -20, 40e6);
        _useLeftPosition(bob, -20, -10, 40e6);

        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[]
            memory reserveParams = new IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[](4);

        reserveParams[0] = _burnParamsRight(address(pool), 10, 20, 4e18);
        reserveParams[1] = _burnParamsRight(address(pool), 20, 30, 4e18);
        reserveParams[2] = _burnParamsLeft(address(pool), -30, -20, 40e6);
        reserveParams[3] = _burnParamsLeft(address(pool), -20, -10, 40e6);

        _batchReserveLiquidity(alice, reserveParams);

        skip(6 hours);

        _unuseRightPosition(bob, 10, 20, 4e18);

        _unuseRightPosition(bob, 20, 30, 4e18);
        _unuseLeftPosition(bob, -30, -20, 40e6);
        _unuseLeftPosition(bob, -20, -10, 40e6);

        vm.prank(alice);
        reserveProxy.batchWithdrawReserveLiquidity(handlerV2, reserveParams);

        assertApproxEqRel(
            mock0.balanceOf(alice),
            8e18,
            0.0001e18,
            "alice's mock0 balance should be 8e18 (delta 0.01%)"
        );
        assertApproxEqRel(
            mock1.balanceOf(alice),
            80e6,
            0.0001e18,
            "alice's mock1 balance should be 80e6 (delta 0.01%)"
        );
    }

    function test_batchWithdrawReserveLiquidity_coolDownNotPassed() public {}

    function test_batchWithdrawReserveLiquidity_liquidityNotEnough() public {}

    function _batchReserveLiquidity(
        address user,
        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams[] memory reserveParams
    ) internal {
        vm.startPrank(user);
        // create a new reserve helper for the given handler and user
        if (address(reserveProxy.reserveHelpers(reserveProxy.helperId(user, handlerV2))) == address(0)) {
            ReserveHelper helper = reserveProxy.createMyReserveHelper(handlerV2);
            IERC6909(address(handlerV2)).setOperator(address(helper), true);
        }
        reserveProxy.batchReserveLiquidity(handlerV2, reserveParams);
        vm.stopPrank();
    }

    function reservedLiquidity(
        address user,
        address pool_,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128) {
        ReserveHelper helper = reserveProxy.reserveHelpers(reserveProxy.helperId(user, handlerV2));
        uint256 tokenId = uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)));
        return handlerV2.reservedLiquidityPerUser(tokenId, address(helper)).liquidity;
    }
}
