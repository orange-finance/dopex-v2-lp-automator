// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase, custom-errors */
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";
import {DealExtension} from "../../helper/DealExtension.t.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "./../../../contracts/lib/UniswapV3SingleTickLiquidityLibV2.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../helper/DopexV2Helper.t.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract TestUniswapV3SingleTickLiquidityLibV2 is WETH_USDC_Fixture, DealExtension {
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;

    function setUp() public override {
        vm.createSelectFork("arb", 181171193);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
    }

    function test_tokenId() public {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _currentTick, _currentTick + _spacing);
        assertEq(
            _tokenId,
            uint256(keccak256(abi.encode(handlerV2, address(pool), address(0), _currentTick, _currentTick + _spacing)))
        );
    }

    function test_redeemableLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        dealUsdc(address(this), 1000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        int24 _tickLower = _currentTick - (_currentTick % _spacing) + _spacing;
        int24 _tickUpper = _tickLower + _spacing;

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _tickLower, _tickUpper);
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        uint256 _liquidity = 1000e6;
        _mintDopexPosition(_tickLower, _tickUpper, uint128(_liquidity));
        (, uint128 _redeemable, ) = handlerV2.positionDetail(address(this), _tokenId);

        // NOTE: liquidity is rounded down when shares are converted to liquidity
        assertEq(_redeemable, _liquidity - 1, "all liquidity redeemable (rounded down)");
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 599999999);
        (, _redeemable, ) = handlerV2.positionDetail(address(this), _tokenId);
        _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        assertEq(_redeemable, _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed, "partial liquidity redeemable");

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 400000000);
        (, _redeemable, ) = handlerV2.positionDetail(address(this), _tokenId);
        _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        assertEq(_redeemable, 0, "no liquidity redeemable");
    }

    function test_redeemableLiquidity_shouldNotUnderflow() public {
        deal(address(WETH), address(this), 10000 ether);
        dealUsdc(address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 _currentLower = pool.currentLower();

        int24 _tickLower = _currentLower - 10;
        int24 _tickUpper = _currentLower;

        _mintDopexPosition(_tickLower, _tickUpper, pool.singleLiqLeft(_tickLower, 100_000e6));

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _tickLower, _tickUpper);

        uint128 _twoThirdOfFreeLiquidity = (pool.freeLiquidityOfTick(address(0), _tickLower) * 2) / 3;
        // use two-third of the liquidity
        _useDopexPosition(_tickLower, _tickUpper, _twoThirdOfFreeLiquidity);

        // reserve same amount of liquidity
        // then totalLiquidity < liquidityUsed = reservedLiquidity
        _reserveDopexPosition(_tickLower, _tickUpper, _twoThirdOfFreeLiquidity);

        (, uint128 _redeemable, ) = handlerV2.positionDetail(address(this), _tokenId);

        // redeemable liquidity (totalLiquidity - liquidityUsed) should not underflow. It should be 0
        assertEq(0, _redeemable);
    }

    function test_lockedLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        dealUsdc(address(this), 1000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        int24 _tickLower = _currentTick - (_currentTick % _spacing) + _spacing;
        int24 _tickUpper = _tickLower + _spacing;

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _tickLower, _tickUpper);
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        // ! actual liquidity minted to the contract is 999999999
        _mintDopexPosition(_tickLower, _tickUpper, 1000e6);
        (, , uint128 _locked) = handlerV2.positionDetail(address(this), _tokenId);
        //
        assertEq(_locked, 0, "no liquidity locked");

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        _useDopexPosition(_tickLower, _tickUpper, 599999999);
        (, , _locked) = handlerV2.positionDetail(address(this), _tokenId);
        _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        assertEq(
            _locked,
            999999999 - (_tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed),
            "partial liquidity locked (rounded down)"
        );

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 400000000);
        (, , _locked) = handlerV2.positionDetail(address(this), _tokenId);
        _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        assertEq(_locked, 999999999, "all liquidity locked (rounded down)");
    }

    function test_lockedLiquidity_anotherMinterExists() public {
        deal(address(WETH), address(this), 10000 ether);
        dealUsdc(address(this), 1000_000e6);
        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        deal(address(WETH), alice, 10000 ether);
        dealUsdc(alice, 1000_000e6);
        vm.startPrank(alice);
        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);
        vm.stopPrank();

        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        int24 _tickLower = _currentTick - (_currentTick % _spacing) + _spacing;
        int24 _tickUpper = _tickLower + _spacing;

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _tickLower, _tickUpper);
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        uint256 _liquidity = 1000e6;
        _mintDopexPosition(_tickLower, _tickUpper, uint128(_liquidity));
        (, , uint128 _locked) = handlerV2.positionDetail(address(this), _tokenId);

        assertEq(_locked, 0, "no liquidity locked");

        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tokenIdInfo = handlerV2.tokenIds(_tokenId);

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(alice, address(this), true);
        vm.prank(alice);
        _mintDopexPosition(_tickLower, _tickUpper, uint128(_liquidity));

        _tokenIdInfo = handlerV2.tokenIds(_tokenId);
        (, , _locked) = handlerV2.positionDetail(address(this), _tokenId);

        assertEq(_locked, 0, "no liquidity locked");
    }

    function test_lockedLiquidity_shouldNotUnderflow() public {
        deal(address(WETH), address(this), 10000 ether);
        dealUsdc(address(this), 1_000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDC.approve(address(manager), type(uint256).max);

        int24 _currentLower = pool.currentLower();

        int24 _tickLower = _currentLower - 10;
        int24 _tickUpper = _currentLower;

        uint128 _mintLiquidity = pool.singleLiqLeft(_tickLower, 100_000e6);

        _mintDopexPosition(_tickLower, _tickUpper, _mintLiquidity);

        uint128 _twoThirdOfFreeLiquidity = (pool.freeLiquidityOfTick(address(0), _tickLower) * 2) / 3;
        // use two-third of the liquidity
        _useDopexPosition(_tickLower, _tickUpper, _twoThirdOfFreeLiquidity);

        // reserve same amount of liquidity
        _reserveDopexPosition(_tickLower, _tickUpper, _twoThirdOfFreeLiquidity);

        uint256 _tokenId = handlerV2.tokenId(address(pool), address(0), _tickLower, _tickUpper);
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _ti = handlerV2.tokenIds(_tokenId);

        // then totalLiquidity < liquidityUsed = reservedLiquidity
        assertLt(_ti.totalLiquidity, _ti.liquidityUsed);

        // locked liquidity calculation should not underflow.
        uint256 _expectLocked = handlerV2.convertToAssets(
            uint128(handlerV2.balanceOf(address(this), _tokenId)),
            _tokenId
        ) - 1;

        (, , uint128 _locked) = handlerV2.positionDetail(address(this), _tokenId);

        assertEq(_expectLocked, _locked);
    }

    function _mintDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidity) internal {
        IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams
            memory _params = IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: lowerTick,
                tickUpper: upperTick,
                liquidity: liquidity
            });

        manager.mintPosition(handlerV2, abi.encode(_params));
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

    function _reserveDopexPosition(int24 lowerTick, int24 upperTick, uint128 liquidityToReserve) internal {
        uint128 _shares = handlerV2.convertToShares(
            liquidityToReserve,
            handlerV2.tokenId(address(pool), address(0), lowerTick, upperTick)
        );

        IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams
            memory _params = IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                pool: address(pool),
                hook: address(0),
                tickLower: lowerTick,
                tickUpper: upperTick,
                shares: _shares
            });

        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, ) = address(handlerV2).call(abi.encodeWithSignature("reserveLiquidity(bytes)", abi.encode(_params)));
        require(ok, "reserveLiquidity failed");
    }
}
