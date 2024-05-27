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

import {ReserveHelper} from "../contracts/periphery/reserve-liquidity/ReserveHelper.sol";
import {ReserveProxy} from "../contracts/periphery/reserve-liquidity/ReserveProxy.sol";

import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

import {IERC6909} from "../contracts/vendor/dopexV2/IERC6909.sol";
import {IStrykeHandlerV2} from "../contracts/periphery/reserve-liquidity/IStrykeHandlerV2.sol";

interface IWhitelist {
    function whitelistedApps(address app) external view returns (bool);
    function updateWhitelistedApps(address app, bool whitelisted) external;
}

interface IHandlerMint {
    struct MintPositionParams {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    function mintPositionHandler(
        address context,
        bytes calldata mintPositionData
    ) external returns (uint256 sharesMinted);
}

interface IHandlerUse {
    struct UsePositionParams {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityToUse;
    }

    struct UnusePositionParams {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityToUnuse;
    }

    function usePositionHandler(
        bytes calldata usePositionHandler
    ) external returns (address[] memory tokens, uint256[] memory amounts, uint256 liquidityUsed);

    function unusePositionHandler(
        bytes calldata _unusePositionData
    ) external returns (uint256[] memory amounts, uint256 liquidityUnused);
}

abstract contract Base is Test {
    MockERC20 public mock0 = MockERC20(address(0x10));
    MockERC20 public mock1 = MockERC20(address(0x20));
    // not used in test. so make uninitialized
    address public weth9 = address(0);

    IUniswapV3Pool public pool;
    IUniswapV3Factory public factory;
    ISwapRouter public router;

    IDopexV2PositionManager public manager;
    IStrykeHandlerV2 public handlerV2;

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

    function deployUniHandlerV2(address factory_, address swapRouter) internal returns (IStrykeHandlerV2 handler_) {
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

    function _mintRightPosition(
        address to,
        int24 tickLower,
        int24 tickUpper,
        uint256 token0
    ) internal returns (uint256) {
        mock0.approve(address(handlerV2), token0);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0
        );
        return _mintPosition(to, tickLower, tickUpper, liquidity);
    }

    function _mintLeftPosition(
        address to,
        int24 tickLower,
        int24 tickUpper,
        uint256 token1
    ) internal returns (uint256) {
        mock1.approve(address(handlerV2), token1);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token1
        );
        return _mintPosition(to, tickLower, tickUpper, liquidity);
    }

    function _mintPosition(address to, int24 tickLower, int24 tickUpper, uint128 liquidity) internal returns (uint256) {
        bytes memory mint = abi.encode(
            IHandlerMint.MintPositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity
            })
        );

        return IHandlerMint(address(handlerV2)).mintPositionHandler(to, mint);
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
        bool whitelisted = IWhitelist(address(handlerV2)).whitelistedApps(useFor);
        if (!whitelisted) {
            IWhitelist(address(handlerV2)).updateWhitelistedApps(useFor, true);
        }
        bytes memory use = abi.encode(
            IHandlerUse.UsePositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityToUse: liquidity
            }),
            ""
        );

        vm.prank(useFor);
        IHandlerUse(address(handlerV2)).usePositionHandler(use);
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
        bool whitelisted = IWhitelist(address(handlerV2)).whitelistedApps(unuseFor);
        if (!whitelisted) {
            IWhitelist(address(handlerV2)).updateWhitelistedApps(unuseFor, true);
        }
        bytes memory unuse = abi.encode(
            IHandlerUse.UnusePositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityToUnuse: liquidity
            }),
            ""
        );

        vm.prank(unuseFor);
        IHandlerUse(address(handlerV2)).unusePositionHandler(unuse);
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
        deal(address(mock0), address(this), 20e18);
        deal(address(mock1), address(this), 200e6);

        // first minter receive 1 less shares
        _mintRightPosition(carol, 10, 20, 5e18);
        _mintRightPosition(carol, 20, 30, 5e18);
        _mintLeftPosition(carol, -30, -20, 50e6);
        _mintLeftPosition(carol, -20, -10, 50e6);

        uint256[] memory aliceMintShares = new uint256[](4);
        uint256[] memory aliceMintLiquidities = new uint256[](4);

        aliceMintShares[0] = _mintRightPosition(alice, 10, 20, 5e18);
        aliceMintShares[1] = _mintRightPosition(alice, 20, 30, 5e18);
        aliceMintShares[2] = _mintLeftPosition(alice, -30, -20, 50e6);
        aliceMintShares[3] = _mintLeftPosition(alice, -20, -10, 50e6);

        aliceMintLiquidities[0] = tickSharesToAssets(aliceMintShares[0], address(pool), 10, 20);
        aliceMintLiquidities[1] = tickSharesToAssets(aliceMintShares[1], address(pool), 20, 30);
        aliceMintLiquidities[2] = tickSharesToAssets(aliceMintShares[2], address(pool), -30, -20);
        aliceMintLiquidities[3] = tickSharesToAssets(aliceMintShares[3], address(pool), -20, -10);

        _useRightPosition(bob, 10, 20, 9.9e18);
        _useRightPosition(bob, 20, 30, 9.9e18);
        _useLeftPosition(bob, -30, -20, 99e6);
        _useLeftPosition(bob, -20, -10, 99e6);

        IStrykeHandlerV2.ReserveShare[] memory reserveParams = new IStrykeHandlerV2.ReserveShare[](4);

        reserveParams[0] = tickPositionInShare(alice, address(pool), 10, 20);
        reserveParams[1] = tickPositionInShare(alice, address(pool), 20, 30);
        reserveParams[2] = tickPositionInShare(alice, address(pool), -30, -20);
        reserveParams[3] = tickPositionInShare(alice, address(pool), -20, -10);

        IStrykeHandlerV2.ReserveLiquidity[] memory reserves = _batchReserveLiquidity(alice, reserveParams);

        assertEq(reserves.length, 4, "reserves.length should be 4");
        assertEq(reserves[0].liquidity, aliceMintLiquidities[0], "reserves[0].shares should be aliceMintLiquidities[0]"); // prettier-ignore
        assertEq(reserves[1].liquidity, aliceMintLiquidities[1], "reserves[1].shares should be aliceMintLiquidities[1]"); // prettier-ignore
        assertEq(reserves[2].liquidity, aliceMintLiquidities[2], "reserves[2].shares should be aliceMintLiquidities[2]"); // prettier-ignore
        assertEq(reserves[3].liquidity, aliceMintLiquidities[3], "reserves[3].shares should be aliceMintLiquidities[3]"); // prettier-ignore

        assertEq(reservedLiquidity(alice, address(pool), 10, 20), aliceMintLiquidities[0], "reservedLiquidity(10,20) should be aliceMintLiquidities[0]"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), 20, 30), aliceMintLiquidities[1], "reservedLiquidity(20,30) should be aliceMintLiquidities[1]"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), -30, -20), aliceMintLiquidities[2], "reservedLiquidity(-30,-20) should be aliceMintLiquidities[2]"); // prettier-ignore
        assertEq(reservedLiquidity(alice, address(pool), -20, -10), aliceMintLiquidities[3], "reservedLiquidity(-20,-10) should be aliceMintLiquidities[3]"); // prettier-ignore
    }

    function test_batchWithdrawReserveLiquidity() public {
        deal(address(mock0), address(this), 20e18);
        deal(address(mock1), address(this), 200e6);

        // first minter receive 1 less shares
        _mintRightPosition(carol, 10, 20, 5e18);
        _mintRightPosition(carol, 20, 30, 5e18);
        _mintLeftPosition(carol, -30, -20, 50e6);
        _mintLeftPosition(carol, -20, -10, 50e6);

        _mintRightPosition(alice, 10, 20, 5e18);
        _mintRightPosition(alice, 20, 30, 5e18);
        _mintLeftPosition(alice, -30, -20, 50e6);
        _mintLeftPosition(alice, -20, -10, 50e6);
        _useRightPosition(bob, 10, 20, 9.9e18);
        _useRightPosition(bob, 20, 30, 9.9e18);
        _useLeftPosition(bob, -30, -20, 99e6);
        _useLeftPosition(bob, -20, -10, 99e6);

        IStrykeHandlerV2.ReserveShare[] memory reserveRequest = new IStrykeHandlerV2.ReserveShare[](4);

        reserveRequest[0] = tickPositionInShare(alice, address(pool), 10, 20);
        reserveRequest[1] = tickPositionInShare(alice, address(pool), 20, 30);
        reserveRequest[2] = tickPositionInShare(alice, address(pool), -30, -20);
        reserveRequest[3] = tickPositionInShare(alice, address(pool), -20, -10);

        _batchReserveLiquidity(alice, reserveRequest);

        skip(6 hours);

        _unuseRightPosition(bob, 10, 20, 9.9e18);
        _unuseRightPosition(bob, 20, 30, 9.9e18);
        _unuseLeftPosition(bob, -30, -20, 99e6);
        _unuseLeftPosition(bob, -20, -10, 99e6);

        vm.startPrank(alice);
        reserveProxy.batchWithdrawReserveLiquidity(handlerV2, reserveProxy.reserveHelpers(alice).getReservedTokenIds());
        vm.stopPrank();

        assertEq(tickBalance(alice, address(pool), 10, 20), 0, "tickBalance(10,20) should be 0");
        assertEq(tickBalance(alice, address(pool), 20, 30), 0, "tickBalance(20,30) should be 0");
        assertEq(tickBalance(alice, address(pool), -30, -20), 0, "tickBalance(-30,-20) should be 0");
        assertEq(tickBalance(alice, address(pool), -20, -10), 0, "tickBalance(-20,-10) should be 0");
        assertApproxEqRel(mock0.balanceOf(alice), 10e18, 0.0001e18, "alice's mock0 balance should be 10e18 (delta 0.01%)"); // prettier-ignore
        assertApproxEqRel(mock1.balanceOf(alice), 100e6, 0.0001e18, "alice's mock1 balance should be 100e6 (delta 0.01%)"); // prettier-ignore
    }

    function test_batchWithdrawReserveLiquidity_coolDownNotPassed() public {}

    function test_batchWithdrawReserveLiquidity_liquidityNotEnough() public {}

    function _batchReserveLiquidity(
        address user,
        IStrykeHandlerV2.ReserveShare[] memory reserveParams
    ) internal returns (IStrykeHandlerV2.ReserveLiquidity[] memory positions) {
        vm.startPrank(user);
        // create a new reserve helper for the given handler and user
        if (address(reserveProxy.reserveHelpers(user)) == address(0)) {
            ReserveHelper helper = reserveProxy.createMyReserveHelper(handlerV2);
            IERC6909(address(handlerV2)).setOperator(address(helper), true);
        }
        positions = reserveProxy.batchReserveLiquidity(handlerV2, reserveParams);
        vm.stopPrank();
    }

    function reservedLiquidity(
        address user,
        address pool_,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128) {
        ReserveHelper helper = reserveProxy.reserveHelpers(user);
        uint256 tokenId = uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)));
        return handlerV2.reservedLiquidityPerUser(tokenId, address(helper)).liquidity;
    }

    function tickBalance(
        address user,
        address pool_,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256) {
        return
            handlerV2.balanceOf(
                user,
                uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)))
            );
    }

    function tickPositionInShare(
        address user,
        address pool_,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (IStrykeHandlerV2.ReserveShare memory) {
        return
            IStrykeHandlerV2.ReserveShare({
                pool: pool_,
                hook: address(0),
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: uint128(tickBalance(user, pool_, tickLower, tickUpper))
            });
    }

    function tickSharesToAssets(
        uint256 shares,
        address pool_,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128) {
        return
            handlerV2.convertToAssets(
                uint128(shares),
                uint256(keccak256(abi.encode(handlerV2, pool_, address(0), tickLower, tickUpper)))
            );
    }
}
