// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Fixture.t.sol";

contract TestUniswapV3SingleTickLiquidityLib is Fixture {
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;

    function setUp() public override {
        vm.createSelectFork("arb", 157066571);
        super.setUp();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(this), true);
    }

    function test_tokenId() public {
        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, _currentTick, _currentTick + _spacing);
        assertEq(
            _tokenId,
            uint256(keccak256(abi.encode(uniV3Handler, address(pool), pseudoHook, _currentTick, _currentTick + _spacing)))
        );
    }

    function test_redeemableLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDCE), address(this), 1000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDCE.approve(address(manager), type(uint256).max);

        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        int24 _tickLower = _currentTick - (_currentTick % _spacing) + _spacing;
        int24 _tickUpper = _tickLower + _spacing;

        emit log_named_int("current tick", _currentTick);
        emit log_named_int("lower tick", _tickLower);
        emit log_named_int("upper tick", _tickUpper);

        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, _tickLower, _tickUpper);
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        uint256 _liquidity = 1000e6;
        _mintDopexPosition(_tickLower, _tickUpper, uint128(_liquidity));
        uint256 _redeemable = uniV3Handler.redeemableLiquidity(address(this), _tokenId);

        // NOTE: liquidity is rounded down when shares are converted to liquidity
        assertEq(_redeemable, _liquidity - 1, "all liquidity redeemable (rounded down)");
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 774636314000000);
        _redeemable = uniV3Handler.redeemableLiquidity(address(this), _tokenId);
        _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        assertEq(_redeemable, _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed, "partial liquidity redeemable");

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 278352);
        _redeemable = uniV3Handler.redeemableLiquidity(address(this), _tokenId);
        _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        assertEq(_redeemable, 0, "no liquidity redeemable");
    }

    function test_myLockedLiquidity() public {
        deal(address(WETH), address(this), 10000 ether);
        deal(address(USDCE), address(this), 1000_000e6);

        WETH.approve(address(manager), type(uint256).max);
        USDCE.approve(address(manager), type(uint256).max);

        (, int24 _currentTick, , , , , ) = pool.slot0();
        int24 _spacing = pool.tickSpacing();

        int24 _tickLower = _currentTick - (_currentTick % _spacing) + _spacing;
        int24 _tickUpper = _tickLower + _spacing;

        emit log_named_int("current tick", _currentTick);
        emit log_named_int("lower tick", _tickLower);
        emit log_named_int("upper tick", _tickUpper);

        uint256 _tokenId = uniV3Handler.tokenId(address(pool), pseudoHook, _tickLower, _tickUpper);
        /*/////////////////////////////////////////////////////////////
                            case: shares not used
        /////////////////////////////////////////////////////////////*/

        uint256 _liquidity = 1000e6;
        _mintDopexPosition(_tickLower, _tickUpper, uint128(_liquidity));
        uint256 _locked = uniV3Handler.lockedLiquidity(address(this), _tokenId);

        // NOTE: liquidity is rounded down when shares are converted to liquidity
        assertEq(_locked, 0, "no liquidity locked");
        IUniswapV3SingleTickLiquidityHandlerV2.TokenIdInfo memory _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        /*/////////////////////////////////////////////////////////////
                            case: shares partially used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 774636314000000);
        _locked = uniV3Handler.lockedLiquidity(address(this), _tokenId);
        _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        assertEq(
            _locked,
            _liquidity - (_tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed) - 1,
            "partial liquidity locked (rounded down)"
        );

        /*/////////////////////////////////////////////////////////////
                            case: shares fully used
        /////////////////////////////////////////////////////////////*/

        _useDopexPosition(_tickLower, _tickUpper, 278352);
        _locked = uniV3Handler.lockedLiquidity(address(this), _tokenId);
        _tokenIdInfo = uniV3Handler.tokenIds(_tokenId);

        emit log_named_uint(
            "totalLiquidity - liquidity used",
            _tokenIdInfo.totalLiquidity - _tokenIdInfo.liquidityUsed
        );
        emit log_named_uint("total liquidity", _tokenIdInfo.totalLiquidity);
        emit log_named_uint("liquidity used", _tokenIdInfo.liquidityUsed);

        assertEq(_locked, _liquidity - 1, "all liquidity locked (rounded down)");
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
