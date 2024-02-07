// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {OrangeDopexV2LPAutomator, IOrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";

import {ChainlinkQuoter} from "../../contracts/ChainlinkQuoter.sol";
import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLib} from "../../contracts/lib/UniswapV3SingleTickLiquidityLib.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract Fixture is Test {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;
    using TickMath for int24;
    using stdStorage for StdStorage;

    OrangeDopexV2LPAutomator automator;

    IDopexV2PositionManager manager = IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    address managerOwner = 0xEE82496D3ed1f5AFbEB9B29f3f59289fd899d9D0;

    IUniswapV3SingleTickLiquidityHandlerV2 uniV3Handler =
        IUniswapV3SingleTickLiquidityHandlerV2(0xe11d346757d052214686bCbC860C94363AfB4a9A);
    address pseudoHook = address(uint160(uint256(keccak256(abi.encodePacked("orange.dopex-v2.empty-hook")))));
    address dopexV2OptionMarket = 0x764fA09d0B3de61EeD242099BD9352C1C61D3d27;

    IUniswapV3Pool pool = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    int24 public liquidizeTickBoundary = 20;
    int24 public burnOuterTickBoundary = 25;
    uint256 private swapBufferPip = 1500; //0.15%
    uint256 public liquidizeTriggerAssetsAmount = 2e18; //2 WETH

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address dave = makeAddr("dave");

    function setUp() public virtual {
        automator = new OrangeDopexV2LPAutomator(
            OrangeDopexV2LPAutomator.InitArgs({
                name: "OrangeDopexV2LPAutomator",
                symbol: "ODV2LP",
                admin: address(this),
                manager: manager,
                handler: uniV3Handler,
                handlerHook: pseudoHook,
                router: router,
                pool: pool,
                asset: WETH,
                quoter: new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)),
                assetUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                counterAssetUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                minDepositAssets: 0.01 ether
            })
        );

        automator.setDepositCap(100 ether);
        automator.grantRole(automator.STRATEGIST_ROLE(), address(this));

        automator.quoter().setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        automator.quoter().setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);

        vm.label(address(uniV3Handler), "dopexUniV3Handler");
        vm.label(address(pool), "weth_usdc.e");
        vm.label(address(router), "router");
        vm.label(address(manager), "dopexManager");
        vm.label(address(WETH), "weth");
        vm.label(address(USDCE), "usdc");
        vm.label(address(automator), "automator");
    }

    function _getQuote(address base, address quote, uint128 baseAmount) internal view returns (uint256) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(_currentTick, baseAmount, base, quote);
    }

    function _depositFrom(address account, uint256 amount) internal returns (uint256 shares) {
        IERC20 _asset = automator.asset();
        deal(address(_asset), account, amount);

        vm.startPrank(account);
        _asset.approve(address(automator), amount);
        shares = automator.deposit(amount);
        vm.stopPrank();
    }

    function _mintDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidity) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams memory _params = IUniswapV3SingleTickLiquidityHandlerV2
            .MintPositionParams({
                pool: address(pool),
                hook: pseudoHook,
                tickLower: lowerTick,
                tickUpper: upperTick,
                liquidity: liquidity
            });

        manager.mintPosition(uniV3Handler, abi.encode(_params));
    }

    function _useDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidityToUse) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.UsePositionParams memory _params = IUniswapV3SingleTickLiquidityHandlerV2
            .UsePositionParams({
                pool: address(pool),
                tickLower: lowerTick,
                tickUpper: upperTick,
                liquidityToUse: liquidityToUse
            });

        manager.usePosition(uniV3Handler, abi.encode(_params));
    }

    function _tokenInfo(int24 lower) internal view returns (IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory) {
        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, lower, lower + pool.tickSpacing());
        return uniV3Handler.tokenIds(_tokenId);
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
        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, lowerTick, lowerTick + pool.tickSpacing());
        uint128 _liquidity = uniV3Handler.convertToAssets(uint128(uniV3Handler.balanceOf(account, _tokenId)), _tokenId);

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

    function _positionToFreeAssets(int24 lowerTick, address account) internal view returns (uint256) {
        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, lowerTick, lowerTick + pool.tickSpacing());

        uint256 _liquidity = uniV3Handler.redeemableLiquidity(account, _tokenId);
        (, int24 _currentTick, , , , , ) = pool.slot0();

        (uint256 _amount0, uint256 _amount1) = LiquidityAmounts.getAmountsForLiquidity(
            _currentTick.getSqrtRatioAtTick(),
            lowerTick.getSqrtRatioAtTick(),
            (lowerTick + pool.tickSpacing()).getSqrtRatioAtTick(),
            uint128(_liquidity)
        );

        IERC20 _baseAsset = pool.token0() == address(automator.asset()) ? IERC20(pool.token1()) : IERC20(pool.token0());
        IERC20 _quoteAsset = pool.token0() == address(automator.asset())
            ? IERC20(pool.token0())
            : IERC20(pool.token1());

        uint256 _quote = pool.token0() == address(automator.asset()) ? _amount0 : _amount1;
        uint256 _base = pool.token0() == address(automator.asset()) ? _amount1 : _amount0;

        return _quote + _getQuote(address(_baseAsset), address(_quoteAsset), uint128(_base));
    }

    function _outOfRangeBelow(int24 mulOffset) internal view returns (int24 tick, uint256 tokenId) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        tick = _currentTick - (_currentTick % _spacing) - _spacing * (mulOffset + 1);
        tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, tick, tick + _spacing);
    }

    function _outOfRangeAbove(int24 mulOffset) internal view returns (int24 tick, uint256 tokenId) {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        tick = _currentTick - (_currentTick % _spacing) + _spacing * mulOffset;
        tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, tick, tick + _spacing);
    }

    // function _deployOrangeDopexV2LPAutomator(
    //     address admin,
    //     address strategist,
    //     IUniswapV3Pool pool_,
    //     IERC20 asset,
    //     uint256 minDepositAssets,
    //     uint256 depositCap
    // ) internal {
    //     automator = new OrangeDopexV2LPAutomator({
    //         name: "OrangeDopexV2LPAutomator",
    //         symbol: "ODV2LP",
    //         admin: admin,
    //         manager_: manager,
    //         handler_: uniV3Handler,
    //         router_: router,
    //         pool_: pool_,
    //         asset_: asset,
    //         minDepositAssets_: minDepositAssets
    //     });

    //     automator.setDepositCap(depositCap);
    //     automator.grantRole(automator.STRATEGIST_ROLE(), strategist);
    // }

    function _rebalanceMintSingle(int24 lowerTick, uint128 liquidity) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new OrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new OrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function _rebalanceBurnSingle(int24 lowerTick, uint128 liquidity) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksBurn = new OrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksBurn[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            new OrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            _ticksBurn,
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }
}
