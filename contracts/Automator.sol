// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3SingleTickLiquidityHandler} from "./vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {UniswapV3SingleTickLiquidityLib} from "./lib/UniswapV3SingleTickLiquidityLib.sol";
import {IDopexV2PositionManager} from "./vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

interface IMulticallProvider {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

contract Automator is ERC20, AccessControlEnumerable {
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandler;

    struct LockedDopexShares {
        uint256 tokenId;
        uint256 shares;
    }

    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    IDopexV2PositionManager public immutable manager;
    IUniswapV3SingleTickLiquidityHandler public immutable handler;

    IUniswapV3Pool public immutable pool;
    ISwapRouter public immutable router;

    IERC20 public immutable asset;
    IERC20 public immutable counterAsset;

    int24 public immutable poolTickSpacing;

    EnumerableSet.UintSet activeTicks;

    error LengthMismatch();
    error InvalidRebalanceParams();
    error MinAssetsRequired();

    constructor(
        address admin,
        IDopexV2PositionManager manager_,
        IUniswapV3SingleTickLiquidityHandler handler_,
        ISwapRouter router_,
        IUniswapV3Pool pool_,
        IERC20 asset_
    ) ERC20("Automator", "AUTO", 18) {
        manager = manager_;
        handler = handler_;
        router = router_;
        pool = pool_;
        asset = asset_;
        counterAsset = pool_.token0() == address(asset_) ? IERC20(pool_.token1()) : IERC20(pool_.token0());
        poolTickSpacing = pool_.tickSpacing();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // TODO: implement
    function totalAssets() public view returns (uint256) {}

    // TODO: implement
    function previewRedeem() public view returns (uint256, LockedDopexShares[] memory) {}

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 _supply = totalSupply;

        return _supply == 0 ? assets : assets.mulDivDown(_supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply;

        return _supply == 0 ? shares : shares.mulDivDown(totalAssets(), _supply);
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        if (totalSupply == 0) {
            uint256 _dead = 10 ** decimals / 1000;
            shares = assets - _dead;

            _mint(msg.sender, shares);
        } else {
            shares = convertToShares(assets);

            _mint(msg.sender, shares);
        }

        asset.safeTransferFrom(msg.sender, address(this), assets);
    }

    function redeem(
        uint256 shares,
        uint256 minAssets // use sqrtPriceLimitX96 instead ?
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares) {
        uint256 _length = activeTicks.length();
        int24 _lt;
        uint256 _tid;
        uint256 _shareLocked;
        uint256 _shareRedeemable;
        uint256 j;

        uint256 _preBase = counterAsset.balanceOf(address(this));
        uint256 _preQuote = asset.balanceOf(address(this));

        for (uint256 i = 0; i < _length; i++) {
            _lt = int24(uint24(activeTicks.at(i)));
            _tid = handler.tokenId(address(pool), _lt, _lt + poolTickSpacing);
            _shareRedeemable = handler.myRedeemableLiquidity(_tid);
            _shareLocked = handler.myLockedLiquidity(_tid);

            // locked share is transferred to the user
            if (_shareLocked > 0) {
                unchecked {
                    lockedDopexShares[j++] = LockedDopexShares({tokenId: _tid, shares: _shareLocked});
                }

                handler.safeTransferFrom(address(this), msg.sender, _tid, _shareLocked, "");
            }

            // redeemable share is burned
            if (_shareRedeemable > 0) {
                manager.burnPosition(
                    handler,
                    abi.encode(
                        IUniswapV3SingleTickLiquidityHandler.BurnPositionParams({
                            pool: address(pool),
                            tickLower: _lt,
                            tickUpper: _lt + poolTickSpacing,
                            shares: _shareRedeemable.toUint128()
                        })
                    )
                );
            }
        }

        uint256 _payBase = counterAsset.balanceOf(address(this)) - _preBase;

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(counterAsset),
                tokenOut: address(asset),
                fee: pool.fee(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _payBase,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        if ((assets = asset.balanceOf(address(this)) - _preQuote) < minAssets) revert MinAssetsRequired();

        _burn(msg.sender, shares);

        asset.safeTransfer(msg.sender, assets);
    }

    struct MintParams {
        int24 tick;
        uint128 liquidity;
    }

    struct BurnParams {
        int24 tick;
        uint128 shares;
    }

    function rebalance(
        MintParams[] calldata mintParams,
        BurnParams[] calldata burnParams
    ) external onlyRole(STRATEGIST_ROLE) {
        uint256 _mintLength = mintParams.length;
        uint256 _burnLength = burnParams.length;

        bytes[] memory _mintCalldataBatch = new bytes[](_mintLength);
        int24 _lt;
        int24 _ut;
        uint256 _posId;
        for (uint256 i = 0; i < _mintLength; i++) {
            _lt = mintParams[i].tick;
            _ut = _lt + poolTickSpacing;
            _mintCalldataBatch[i] = abi.encodeWithSelector(
                IDopexV2PositionManager.mintPosition.selector,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandler.MintPositionParams({
                        pool: address(pool),
                        tickLower: _lt,
                        tickUpper: _ut,
                        liquidity: mintParams[i].liquidity
                    })
                )
            );

            // If the position is not active, push it to the active ticks
            _posId = uint256(keccak256(abi.encode(handler, pool, _lt, _ut)));
            if (handler.balanceOf(address(this), _posId) == 0) activeTicks.add(uint256(uint24(_lt)));
        }

        bytes[] memory _burnCalldataBatch = new bytes[](_burnLength);
        for (uint256 i = 0; i < _burnLength; i++) {
            _lt = burnParams[i].tick;
            _ut = _lt + poolTickSpacing;
            _burnCalldataBatch[i] = abi.encodeWithSelector(
                IDopexV2PositionManager.burnPosition.selector,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandler.BurnPositionParams({
                        pool: address(pool),
                        tickLower: _lt,
                        tickUpper: _ut,
                        shares: burnParams[i].shares
                    })
                )
            );

            // if all shares will be burned, pop the active tick
            _posId = uint256(keccak256(abi.encode(handler, pool, _lt, _ut)));
            if (handler.balanceOf(address(this), _posId) - burnParams[i].shares == 0)
                activeTicks.remove(uint256(uint24(_lt)));
        }

        IMulticallProvider(address(handler)).multicall(_mintCalldataBatch);
        IMulticallProvider(address(handler)).multicall(_burnCalldataBatch);
    }

    // function rebalance(
    //     bytes[] calldata mintBatchCalldata,
    //     bytes[] calldata burnBatchCalldata,
    //     int24[] calldata activeTicks,
    //     int24[] calldata inactiveTicks
    // ) external {
    //     IMulticallProvider(address(handler)).multicall(mintBatchCalldata);
    //     IMulticallProvider(address(handler)).multicall(burnBatchCalldata);
    // }
}
