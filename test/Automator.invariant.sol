// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Automator} from "../contracts/Automator.sol";

import {IUniswapV3SingleTickLiquidityHandler} from "../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {IDopexV2PositionManager} from "../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {LiquidityAmounts} from "../contracts/vendor/uniswapV3/LiquidityAmounts.sol";
import {UniswapV3SingleTickLiquidityLib} from "../contracts/lib/UniswapV3SingleTickLiquidityLib.sol";
import {TickMath} from "../contracts/vendor/uniswapV3/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {IAutomator} from "../contracts/interfaces/IAutomator.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract TestAutomatorInvariant is Test {
    address constant DOPEX_OWNER = 0x2c9bC901f39F847C2fe5D2D7AC9c5888A2Ab8Fcf;

    AutomatorHandler handler;
    Automator automator;

    IUniswapV3Pool pool = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IUniswapV3SingleTickLiquidityHandler uniV3Handler =
        IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);
    IDopexV2PositionManager manager = IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    function setUp() public {
        vm.createSelectFork("arb", 151299689);

        automator = new Automator({
            admin: address(this),
            manager_: manager,
            handler_: uniV3Handler,
            router_: router,
            pool_: pool,
            asset_: WETH,
            minDepositAssets_: 0.01 ether
        });

        automator.setDepositCap(100 ether);
        handler = new AutomatorHandler(automator);
        automator.grantRole(automator.STRATEGIST_ROLE(), address(handler));

        targetContract(address(handler));
        /**
         * NOTE: this is a hack to cache the forked chain's state.
         * transactions in the invariant test are from random senders so the state is not cached.
         * so we just send a transaction from a dummy sender to cache the state.
         * then use vm.prank to set the sender to the actual sender.
         */
        targetSender(makeAddr("dummy"));

        vm.label(address(uniV3Handler), "dopexUniV3Handler");
        vm.label(address(pool), "weth_usdc.e");
        vm.label(address(router), "router");
        vm.label(address(manager), "dopexManager");
        vm.label(address(WETH), "weth");
        vm.label(address(USDCE), "usdc");
        vm.label(address(automator), "automator");
    }

    function invariant_sumOfSharesMatchesTotalSupply() public {
        assertEq(handler.totalMinted(), automator.totalSupply(), "total minted shares == total supply");
    }
}

contract AutomatorHandler is Test {
    using FixedPointMathLib for uint256;
    using TickMath for int24;
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandler;

    Automator automator;

    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address carol = vm.addr(3);
    address dave = vm.addr(4);

    address[] actors = [alice, bob, carol, dave];
    address currentActor;

    uint256 public totalMinted;

    error UniswapV3SingleTickLiquidityHandler__InRangeLP();

    modifier useActor(uint256 index) {
        currentActor = actors[bound(index, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(Automator automator_) {
        automator = automator_;

        vm.label(address(alice), "alice");
        vm.label(address(bob), "bob");
        vm.label(address(carol), "carol");
        vm.label(address(dave), "dave");
    }

    function deposit(uint256 assets, uint256 actorIndex) external useActor(actorIndex) {
        // assets = bound(assets, automator.minDepositAssets(), automator.depositCap());
        assets = bound(assets, 0, automator.depositCap() * 2);

        IERC20 _asset = automator.asset();
        deal(address(_asset), currentActor, assets);

        _asset.approve(address(automator), assets);

        uint256 _preAssets = _asset.balanceOf(currentActor);
        uint256 _preShares = automator.balanceOf(currentActor);
        uint256 _sharesMinted;

        /*////////////////////////////////////////////////////////////
                        case: zero deposit will revert
        ////////////////////////////////////////////////////////////*/
        if (assets == 0) {
            vm.expectRevert(Automator.AmountZero.selector);
            automator.deposit(assets);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: too small deposit will revert
        ////////////////////////////////////////////////////////////*/
        if (assets < automator.minDepositAssets()) {
            vm.expectRevert(Automator.DepositTooSmall.selector);
            automator.deposit(assets);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: deposit cap exceeded will revert
        ////////////////////////////////////////////////////////////*/
        if (assets > automator.depositCap()) {
            vm.expectRevert(Automator.DepositCapExceeded.selector);
            automator.deposit(assets);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: first deposit
        ////////////////////////////////////////////////////////////*/
        if (automator.totalSupply() == 0) {
            _sharesMinted = automator.deposit(assets);
            uint256 _sharesDead = 10 ** automator.decimals() / 1000;
            assertEq(_sharesMinted, assets - _sharesDead, "first deposit: deducts dead shares");
            assertEq(_asset.balanceOf(currentActor), _preAssets - assets, "first deposit: user assets transferred");
            assertEq(
                automator.balanceOf(currentActor),
                _preShares + _sharesMinted,
                "first deposit: user shares minted"
            );

            totalMinted += _sharesMinted;
            totalMinted += _sharesDead;
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: not first deposit
        ////////////////////////////////////////////////////////////*/
        uint256 _totalAssets = automator.totalAssets();
        uint256 _totalSupply = automator.totalSupply();
        emit log_named_uint("total assets", _totalAssets);
        emit log_named_uint("total supply", _totalSupply);

        assertNotEq(_totalAssets, 0, "not first deposit: total assets != 0");
        _sharesMinted = automator.deposit(assets);
        assertEq(_sharesMinted, assets.mulDivDown(_totalSupply, _totalAssets), "not first deposit: shares minted");

        totalMinted += _sharesMinted;
    }

    function redeem(uint256 shares, uint256 actorIndex) external useActor(actorIndex) {
        shares = bound(shares, 0, automator.balanceOf(currentActor) * 2);

        /*////////////////////////////////////////////////////////////
                        case: zero shares will revert
        ////////////////////////////////////////////////////////////*/
        if (shares == 0) {
            emit log_string("case: zero shares will revert");
            vm.expectRevert(Automator.AmountZero.selector);
            automator.redeem(shares, 0);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: shares > balance will revert
        ////////////////////////////////////////////////////////////*/
        if (shares > automator.balanceOf(currentActor)) {
            emit log_string("case: shares > balance will revert");
            vm.expectRevert();
            automator.redeem(shares, 0);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: too small shares will revert
        ////////////////////////////////////////////////////////////*/
        if (automator.convertToAssets(shares) == 0) {
            emit log_string("case: too small shares will revert");
            vm.expectRevert(Automator.SharesTooSmall.selector);
            automator.redeem(shares, 0);
            return;
        }

        /*////////////////////////////////////////////////////////////
                        case: normal redeem
        ////////////////////////////////////////////////////////////*/
        emit log_string("case: normal redeem");
        uint256 _minAssets = automator.convertToAssets(shares);

        uint256 _preAssets = automator.asset().balanceOf(currentActor);
        uint256 _preShares = automator.balanceOf(currentActor);

        (uint256 _assets, ) = automator.redeem(shares, _minAssets);

        // FIXME: consider locked dopex liquidity
        // uint256 _totalAssets = automator.totalAssets();
        // uint256 _totalSupply = automator.totalSupply();
        // assertEq(_assets, shares.mulDivDown(_totalAssets, _totalSupply), "redeem: assets");

        assertEq(automator.asset().balanceOf(currentActor), _preAssets + _assets, "redeem: user assets transferred");
        assertEq(automator.balanceOf(currentActor), _preShares - shares, "redeem: user shares burned");

        totalMinted -= shares;
    }

    // function rebalance(int24 lowerTick, uint128 liquidity, uint256 shares, uint256 positions) external {
    //     (, int24 _currentTick, , , , , ) = automator.pool().slot0();
    //     int24 tickSpacing = automator.pool().tickSpacing();

    //     positions = bound(positions, 0, 5);
    //     lowerTick = int24(
    //         bound(
    //             lowerTick,
    //             _currentTick - tickSpacing * int24(uint24(positions)),
    //             _currentTick + tickSpacing * int24(uint24(positions))
    //         )
    //     );
    //     lowerTick = lowerTick - (lowerTick % tickSpacing);

    //     /*////////////////////////////////////////////////////////////
    //                     case: out of range
    //     ////////////////////////////////////////////////////////////*/

    //     // create params
    //     Automator.MintParams[] memory _mintParams = new Automator.MintParams[](positions);
    //     Automator.RebalanceBurnParams[] memory _burnParams = new Automator.RebalanceBurnParams[](positions);

    //     int24 _lt = lowerTick;
    //     int24 _ut = lowerTick + int24(tickSpacing);
    //     (uint256 j, uint256 k) = (0, 0);

    //     for (uint256 i = 0; i < positions; i++) {
    //         // skip in range ticks
    //         if (_lt <= _currentTick && _currentTick <= _ut) {
    //             _lt += int24(tickSpacing);
    //             _ut += int24(tickSpacing);
    //             continue;
    //         }

    //         // create mint params
    //         uint128 _maxLiquidity = LiquidityAmounts.getLiquidityForAmounts(
    //             _currentTick.getSqrtRatioAtTick(),
    //             _lt.getSqrtRatioAtTick(),
    //             _ut.getSqrtRatioAtTick(),
    //             IERC20(automator.pool().token0()).balanceOf(address(automator)),
    //             IERC20(automator.pool().token1()).balanceOf(address(automator))
    //         ) / uint128(positions);

    //         liquidity = uint128(bound(liquidity, 0, _maxLiquidity));

    //         if (liquidity > 0) _mintParams[k++] = Automator.MintParams({tick: _lt, liquidity: liquidity});

    //         // create burn params
    //         shares = automator.handler().balanceOf(
    //             address(automator),
    //             automator.handler().tokenId(address(automator.pool()), _lt, _ut)
    //         );

    //         if (shares > 0) {
    //             shares = bound(shares, 0, shares);
    //             _burnParams[j++] = Automator.RebalanceBurnParams({tick: _lt, shares: uint128(shares)});
    //         }

    //         _lt += int24(tickSpacing);
    //         _ut += int24(tickSpacing);
    //     }

    //     // shorted _mintParams
    //     Automator.MintParams[] memory _mintParamsShorted = new Automator.MintParams[](k);
    //     for (uint256 i = 0; i < k; i++) {
    //         _mintParamsShorted[i] = _mintParams[i];
    //     }

    //     // shorted _burnParams
    //     Automator.RebalanceBurnParams[] memory _burnParamsShorted = new Automator.RebalanceBurnParams[](j);
    //     for (uint256 i = 0; i < j; i++) {
    //         _burnParamsShorted[i] = _burnParams[i];
    //     }

    //     vm.prank(address(this));
    //     automator.rebalance(_mintParamsShorted, _burnParamsShorted);
    // }

    // TODO: make this work
    function rebalance(int24 lowerTick, uint128 liquidity, uint256 shares, uint256 positions) external {
        (, int24 _currentTick, , , , , ) = automator.pool().slot0();
        int24 tickSpacing = automator.pool().tickSpacing();

        positions = bound(positions, 0, 5);
        lowerTick = int24(
            bound(
                lowerTick,
                _currentTick - tickSpacing * int24(uint24(positions)),
                _currentTick + tickSpacing * int24(uint24(positions))
            )
        );
        lowerTick = lowerTick - (lowerTick % tickSpacing);

        /*////////////////////////////////////////////////////////////
                        case: out of range
        ////////////////////////////////////////////////////////////*/

        // create params
        IAutomator.RebalanceTickInfo[] memory _ticksMint = new IAutomator.RebalanceTickInfo[](positions);
        IAutomator.RebalanceTickInfo[] memory _ticksBurn = new IAutomator.RebalanceTickInfo[](positions);

        int24 _lt = lowerTick;
        int24 _ut = lowerTick + int24(tickSpacing);
        (uint256 j, uint256 k) = (0, 0);

        for (uint256 i = 0; i < positions; i++) {
            // skip in range ticks
            if (_lt <= _currentTick && _currentTick <= _ut) {
                _lt += int24(tickSpacing);
                _ut += int24(tickSpacing);
                continue;
            }

            // create mint params
            uint128 _maxLiquidity = LiquidityAmounts.getLiquidityForAmounts(
                _currentTick.getSqrtRatioAtTick(),
                _lt.getSqrtRatioAtTick(),
                _ut.getSqrtRatioAtTick(),
                IERC20(automator.pool().token0()).balanceOf(address(automator)),
                IERC20(automator.pool().token1()).balanceOf(address(automator))
            ) / uint128(positions);

            liquidity = uint128(bound(liquidity, 0, _maxLiquidity));

            // FIXME: too small liquidity will revert
            // if (liquidity > 0 && automator.checkMintValidity(_lt, _ut))
            if (liquidity > 10000 && automator.checkMintValidity(_lt, _ut))
                _ticksMint[k++] = IAutomator.RebalanceTickInfo({tick: _lt, liquidity: liquidity});

            // create burn params
            shares = automator.handler().balanceOf(
                address(automator),
                automator.handler().tokenId(address(automator.pool()), _lt, _ut)
            );

            if (shares > 0) {
                shares = bound(shares, 0, shares);
                _ticksBurn[j++] = IAutomator.RebalanceTickInfo({
                    tick: _lt,
                    liquidity: automator.handler().convertToAssets(
                        uint128(shares),
                        automator.handler().tokenId(address(automator.pool()), _lt, _ut)
                    )
                });
            }

            _lt += int24(tickSpacing);
            _ut += int24(tickSpacing);
        }

        // shorted _ticksMint
        IAutomator.RebalanceTickInfo[] memory _ticksMintShorted = new IAutomator.RebalanceTickInfo[](k);
        for (uint256 i = 0; i < k; i++) {
            _ticksMintShorted[i] = _ticksMint[i];
        }

        // shorted _ticksBurn
        IAutomator.RebalanceTickInfo[] memory _ticksBurnShorted = new IAutomator.RebalanceTickInfo[](j);
        for (uint256 i = 0; i < j; i++) {
            _ticksBurnShorted[i] = _ticksBurn[i];
        }

        vm.prank(address(this));
        automator.inefficientRebalance(
            _ticksMintShorted,
            _ticksBurnShorted,
            IAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }
}
