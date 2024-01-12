// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeDopexV2LPAutomator} from "./interfaces/IOrangeDopexV2LPAutomator.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LiquidityAmounts} from "./vendor/uniswapV3/LiquidityAmounts.sol";
import {TickMath} from "./vendor/uniswapV3/TickMath.sol";
import {OracleLibrary} from "./vendor/uniswapV3/OracleLibrary.sol";
import {FullMath} from "./vendor/uniswapV3/FullMath.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IUniswapV3SingleTickLiquidityHandler} from "./vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
import {UniswapV3SingleTickLiquidityLib} from "./lib/UniswapV3SingleTickLiquidityLib.sol";
import {AutomatorUniswapV3PoolLib} from "./lib/AutomatorUniswapV3PoolLib.sol";
import {IDopexV2PositionManager} from "./vendor/dopexV2/IDopexV2PositionManager.sol";

import {IERC20Decimals} from "./interfaces/IERC20Extended.sol";

interface IMulticallProvider {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

/**
 * @title OrangeDopexV2LPAutomator
 * @dev Automate liquidity provision for Dopex V2 contract
 * @author Orange Finance
 */
contract OrangeDopexV2LPAutomator is IOrangeDopexV2LPAutomator, ERC20, AccessControlEnumerable, IERC1155Receiver {
    using FixedPointMathLib for uint256;
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using TickMath for int24;
    using AutomatorUniswapV3PoolLib for IUniswapV3Pool;
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandler;

    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    /// @notice max deposit fee percentage is 1%
    uint24 constant MAX_PERF_FEE_PIPS = 100_000;

    IDopexV2PositionManager public immutable manager;
    IUniswapV3SingleTickLiquidityHandler public immutable handler;

    IUniswapV3Pool public immutable pool;
    ISwapRouter public immutable router;

    IERC20 public immutable asset;
    IERC20 public immutable counterAsset;

    int24 public immutable poolTickSpacing;

    uint256 public immutable minDepositAssets;

    uint256 public depositCap;

    /// @notice deposit fee percentage, hundredths of a bip (1 pip = 0.0001%)
    uint24 public depositFeePips;
    address public depositFeeRecipient;

    EnumerableSet.UintSet activeTicks;

    error AddressZero();
    error AmountZero();
    error LengthMismatch();
    error InvalidRebalanceParams();
    error MinAssetsRequired(uint256 minAssets, uint256 actualAssets);
    error TokenAddressMismatch();
    error DepositTooSmall();
    error DepositCapExceeded();
    error SharesTooSmall();
    error InvalidPositionConstruction();
    error FeePipsTooHigh();

    /**
     * @dev Constructor function for OrangeDopexV2LPAutomator contract.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     * @param admin The address of the admin role.
     * @param manager_ The address of the DopexV2PositionManager contract.
     * @param handler_ The address of the UniswapV3SingleTickLiquidityHandler contract.
     * @param router_ The address of the SwapRouter contract.
     * @param pool_ The address of the UniswapV3Pool contract.
     * @param asset_ The address of the ERC20 token used as the deposit asset in this vault.
     * @param minDepositAssets_ The minimum amount of assets that can be deposited.
     */
    constructor(
        string memory name,
        string memory symbol,
        address admin,
        IDopexV2PositionManager manager_,
        IUniswapV3SingleTickLiquidityHandler handler_,
        ISwapRouter router_,
        IUniswapV3Pool pool_,
        IERC20 asset_,
        uint256 minDepositAssets_
    ) ERC20(name, symbol, IERC20Decimals(address(asset_)).decimals()) {
        if (asset_ != IERC20(pool_.token0()) && asset_ != IERC20(pool_.token1())) revert TokenAddressMismatch();

        manager = manager_;
        handler = handler_;
        router = router_;
        pool = pool_;
        asset = asset_;
        counterAsset = pool_.token0() == address(asset_) ? IERC20(pool_.token1()) : IERC20(pool_.token0());
        poolTickSpacing = pool_.tickSpacing();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        minDepositAssets = minDepositAssets_;

        asset_.safeApprove(address(manager_), type(uint256).max);
        asset_.safeApprove(address(router_), type(uint256).max);

        counterAsset.safeApprove(address(manager_), type(uint256).max);
        counterAsset.safeApprove(address(router_), type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    ERC1155 RECEIVER INTERFACE
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

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

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Sets the deposit cap for the automator.
     * @param _depositCap The new deposit cap value.
     * Requirements:
     * - Caller must have the DEFAULT_ADMIN_ROLE.
     */
    function setDepositCap(uint256 _depositCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        depositCap = _depositCap;
    }

    /**
     * @dev Sets the deposit fee pips for a recipient.
     * @param recipient The address of the recipient.
     * @param pips The new deposit fee pips value.
     * Requirements:
     * - Caller must have the DEFAULT_ADMIN_ROLE.
     * - Recipient address must not be zero.
     * - deposit fee pips must not exceed MAX_PERF_FEE_PIPS.
     */
    function setDepositFeePips(address recipient, uint24 pips) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert AddressZero();
        if (pips > MAX_PERF_FEE_PIPS) revert FeePipsTooHigh();

        depositFeeRecipient = recipient;
        depositFeePips = pips;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    VAULT STATE DERIVATION FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function totalAssets() public view returns (uint256) {
        // 1. calculate the total assets in Dopex pools
        uint256 _length = activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = pool.slot0();

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(activeTicks.at(i)));
            _ut = _lt + poolTickSpacing;
            _tid = handler.tokenId(address(pool), _lt, _ut);

            _liquidity = handler.convertToAssets((handler.balanceOf(address(this), _tid)).toUint128(), _tid);

            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                _sqrtRatioX96,
                _lt.getSqrtRatioAtTick(),
                _ut.getSqrtRatioAtTick(),
                _liquidity
            );

            _sum0 += _a0;
            _sum1 += _a1;

            unchecked {
                i++;
            }
        }

        // 2. merge into the total assets in the automator
        (uint256 _base, uint256 _quote) = (counterAsset.balanceOf(address(this)), asset.balanceOf(address(this)));

        if (address(asset) == pool.token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            OracleLibrary.getQuoteAtTick(pool.currentTick(), _base.toUint128(), address(counterAsset), address(asset));
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function freeAssets() public view returns (uint256) {
        // 1. calculate the free assets in Dopex pools
        uint256 _length = activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = pool.slot0();

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(activeTicks.at(i)));
            _ut = _lt + poolTickSpacing;
            _tid = handler.tokenId(address(pool), _lt, _ut);

            _liquidity = handler.redeemableLiquidity(address(this), _tid).toUint128();

            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                _sqrtRatioX96,
                _lt.getSqrtRatioAtTick(),
                _ut.getSqrtRatioAtTick(),
                _liquidity
            );

            _sum0 += _a0;
            _sum1 += _a1;

            unchecked {
                i++;
            }
        }

        // 2. merge into the total assets in the automator
        (uint256 _base, uint256 _quote) = (counterAsset.balanceOf(address(this)), asset.balanceOf(address(this)));

        if (address(asset) == pool.token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            OracleLibrary.getQuoteAtTick(pool.currentTick(), _base.toUint128(), address(counterAsset), address(asset));
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 _supply = totalSupply;

        return _supply == 0 ? assets : assets.mulDivDown(_supply, totalAssets());
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply;

        return _supply == 0 ? shares : shares.mulDivDown(totalAssets(), _supply);
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function getTickAllLiquidity(int24 tick) external view returns (uint128) {
        uint256 _share = handler.balanceOf(address(this), handler.tokenId(address(pool), tick, tick + poolTickSpacing));

        return
            handler.convertToAssets(_share.toUint128(), handler.tokenId(address(pool), tick, tick + poolTickSpacing));
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function getTickFreeLiquidity(int24 tick) external view returns (uint128) {
        return
            handler
                .redeemableLiquidity(address(this), handler.tokenId(address(pool), tick, tick + poolTickSpacing))
                .toUint128();
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function calculateRebalanceSwapParamsInRebalance(
        RebalanceTickInfo[] memory ticksMint,
        RebalanceTickInfo[] memory ticksBurn
    ) external view returns (RebalanceSwapParams memory) {
        uint256 _mintAssets;
        uint256 _mintCAssets;
        uint256 _burnAssets;
        uint256 _burnCAssets;

        if (pool.token0() == address(asset)) {
            (_mintAssets, _mintCAssets) = pool.estimateTotalTokensFromPositions(ticksMint);
            (_burnAssets, _burnCAssets) = pool.estimateTotalTokensFromPositions(ticksBurn);
        } else {
            (_mintCAssets, _mintAssets) = pool.estimateTotalTokensFromPositions(ticksMint);
            (_burnCAssets, _burnAssets) = pool.estimateTotalTokensFromPositions(ticksBurn);
        }

        uint256 _freeAssets = _burnAssets + asset.balanceOf(address(this));
        uint256 _freeCAssets = _burnCAssets + counterAsset.balanceOf(address(this));

        uint256 _assetsShortage;
        if (_mintAssets > _freeAssets) _assetsShortage = _mintAssets - _freeAssets;

        uint256 _counterAssetsShortage;
        if (_mintCAssets > _freeCAssets) _counterAssetsShortage = _mintCAssets - _freeCAssets;

        if (_assetsShortage > 0 && _counterAssetsShortage > 0) revert InvalidPositionConstruction();

        uint256 _maxCounterAssetsUseForSwap;
        if (_assetsShortage > 0) {
            _maxCounterAssetsUseForSwap = _freeCAssets - _mintCAssets;
        }

        uint256 _maxAssetsUseForSwap;
        if (_counterAssetsShortage > 0) {
            _maxAssetsUseForSwap = _freeAssets - _mintAssets;
        }

        return
            RebalanceSwapParams({
                assetsShortage: _assetsShortage,
                counterAssetsShortage: _counterAssetsShortage,
                maxCounterAssetsUseForSwap: _maxCounterAssetsUseForSwap,
                maxAssetsUseForSwap: _maxAssetsUseForSwap
            });
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function getActiveTicks() external view returns (int24[] memory) {
        uint256[] memory _tempTicks = activeTicks.values();
        int24[] memory _activeTicks = new int24[](_tempTicks.length);

        for (uint256 i; i < _tempTicks.length; i++) {
            _activeTicks[i] = int24(uint24(_tempTicks[i]));
        }

        return _activeTicks;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    USER ACTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert AmountZero();
        if (assets < minDepositAssets) revert DepositTooSmall();
        if (assets + totalAssets() > depositCap) revert DepositCapExceeded();

        if (totalSupply == 0) {
            // NOTE: mint small amount of shares to avoid sandwich attack on the first deposit
            // https://mixbytes.io/blog/overview-of-the-inflation-attack
            uint256 _dead = 10 ** decimals / 1000;
            _mint(address(0), _dead);

            unchecked {
                shares = assets - _dead;
            }
        } else {
            shares = convertToShares(assets);
        }

        uint256 _fee = shares.mulDivDown(depositFeePips, 1e6);
        // NOTE: no possibility of minting to the zero address as we can't set zero address with fee pips
        if (_fee > 0) {
            _mint(depositFeeRecipient, _fee);
            shares = shares - _fee;
        }

        _mint(msg.sender, shares);

        asset.safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @dev avoid stack too deep error
    struct RedeemLoopCache {
        int24 lowerTick;
        uint256 tokenId;
        uint256 shareLocked;
        uint256 shareRedeemable;
        uint256 lockedShareIndex;
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function redeem(
        uint256 shares,
        uint256 minAssets
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares) {
        if (shares == 0) revert AmountZero();
        if (convertToAssets(shares) == 0) revert SharesTooSmall();

        uint256 _totalSupply = totalSupply;
        uint256 _preBase = counterAsset.balanceOf(address(this));
        uint256 _preQuote = asset.balanceOf(address(this));

        RedeemLoopCache memory c;
        uint256 _length = activeTicks.length();

        LockedDopexShares[] memory _tempShares = new LockedDopexShares[](_length);

        for (uint256 i = 0; i < _length; ) {
            c.lowerTick = int24(uint24(activeTicks.at(i)));

            c.tokenId = handler.tokenId(address(pool), c.lowerTick, c.lowerTick + poolTickSpacing);
            c.shareRedeemable = uint256(
                handler.convertToShares(handler.redeemableLiquidity(address(this), c.tokenId).toUint128(), c.tokenId)
            ).mulDivDown(shares, _totalSupply);
            c.shareLocked = uint256(
                handler.convertToShares(handler.lockedLiquidity(address(this), c.tokenId).toUint128(), c.tokenId)
            ).mulDivDown(shares, _totalSupply);

            // locked share is transferred to the user
            if (c.shareLocked > 0) {
                unchecked {
                    _tempShares[c.lockedShareIndex++] = LockedDopexShares({tokenId: c.tokenId, shares: c.shareLocked});
                }

                handler.safeTransferFrom(address(this), msg.sender, c.tokenId, c.shareLocked, "");
            }

            // redeemable share is burned
            if (c.shareRedeemable > 0)
                if (handler.paused()) {
                    handler.safeTransferFrom(address(this), msg.sender, c.tokenId, c.shareRedeemable, "");
                } else {
                    _burnPosition(c.lowerTick, c.lowerTick + poolTickSpacing, c.shareRedeemable.toUint128());
                }

            unchecked {
                i++;
            }
        }

        // copy to exact size array
        lockedDopexShares = new LockedDopexShares[](c.lockedShareIndex);
        for (uint256 i = 0; i < c.lockedShareIndex; ) {
            lockedDopexShares[i] = _tempShares[i];

            unchecked {
                i++;
            }
        }

        /**
         * 1. shares.mulDivDown(_preBase, _totalSupply) means the portion of idle base asset
         * 2. counterAsset.balanceOf(address(this)) - _preBase means the base asset from redeemed positions
         */
        uint256 _payBase = shares.mulDivDown(_preBase, _totalSupply) + counterAsset.balanceOf(address(this)) - _preBase;

        if (_payBase > 0) _swapToRedeemAssets(_payBase);

        assets = shares.mulDivDown(_preQuote, _totalSupply) + asset.balanceOf(address(this)) - _preQuote;

        if (assets < minAssets) revert MinAssetsRequired(minAssets, assets);

        _burn(msg.sender, shares);

        asset.safeTransfer(msg.sender, assets);
    }

    function _burnPosition(int24 lowerTick, int24 upperTick, uint128 shares) internal {
        manager.burnPosition(
            handler,
            abi.encode(
                IUniswapV3SingleTickLiquidityHandler.BurnPositionParams({
                    pool: address(pool),
                    tickLower: lowerTick,
                    tickUpper: upperTick,
                    shares: shares
                })
            )
        );
    }

    function _swapToRedeemAssets(uint256 counterAssetsIn) internal {
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(counterAsset),
                tokenOut: address(asset),
                fee: pool.fee(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: counterAssetsIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    STRATEGIST ACTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function checkMintValidity(int24 lowerTick) external view returns (bool) {
        IUniswapV3SingleTickLiquidityHandler.TokenIdInfo memory _ti = handler.tokenIds(
            handler.tokenId(address(pool), lowerTick, lowerTick + poolTickSpacing)
        );

        if (_ti.tokensOwed0 > 0 && _ti.tokensOwed0 < 10) return false;
        if (_ti.tokensOwed1 > 0 && _ti.tokensOwed1 < 10) return false;

        return true;
    }

    /// @inheritdoc IOrangeDopexV2LPAutomator
    function rebalance(
        RebalanceTickInfo[] calldata ticksMint,
        RebalanceTickInfo[] calldata ticksBurn,
        RebalanceSwapParams calldata swapParams
    ) external onlyRole(STRATEGIST_ROLE) {
        uint256 _mintLength = ticksMint.length;
        uint256 _burnLength = ticksBurn.length;

        bytes[] memory _mintCalldataBatch = new bytes[](_mintLength);
        int24 _lt;
        int24 _ut;
        uint256 _posId;
        for (uint256 i = 0; i < _mintLength; ) {
            _lt = ticksMint[i].tick;
            _ut = _lt + poolTickSpacing;

            _mintCalldataBatch[i] = _createMintCalldata(_lt, _ut, ticksMint[i].liquidity);

            // If the position is not active, push it to the active ticks
            _posId = uint256(keccak256(abi.encode(handler, pool, _lt, _ut)));
            if (handler.balanceOf(address(this), _posId) == 0) activeTicks.add(uint256(uint24(_lt)));

            unchecked {
                i++;
            }
        }

        bytes[] memory _burnCalldataBatch = new bytes[](_burnLength);
        uint256 _shares;
        for (uint256 i = 0; i < _burnLength; ) {
            _lt = ticksBurn[i].tick;
            _ut = _lt + poolTickSpacing;

            _posId = uint256(keccak256(abi.encode(handler, pool, _lt, _ut)));
            _shares = handler.convertToShares(ticksBurn[i].liquidity, _posId);
            _burnCalldataBatch[i] = _createBurnCalldata(_lt, _ut, _shares.toUint128());

            // if all shares will be burned, pop the active tick
            if (handler.balanceOf(address(this), _posId) - _shares == 0) activeTicks.remove(uint256(uint24(_lt)));

            unchecked {
                i++;
            }
        }

        // NOTE: burn should be called before mint to receive the assets from the burned position
        if (_burnLength > 0) IMulticallProvider(address(manager)).multicall(_burnCalldataBatch);

        // NOTE: after receiving the assets from the burned position, swap should be called to get the assets for mint
        _swapBeforeRebalanceMint(swapParams);

        if (_mintLength > 0) IMulticallProvider(address(manager)).multicall(_mintCalldataBatch);
    }

    function _swapBeforeRebalanceMint(RebalanceSwapParams calldata swapParams) internal {
        if (swapParams.assetsShortage > 0) {
            router.exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: address(counterAsset),
                    tokenOut: address(asset),
                    fee: pool.fee(),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: swapParams.assetsShortage,
                    amountInMaximum: swapParams.maxCounterAssetsUseForSwap,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        if (swapParams.counterAssetsShortage > 0) {
            router.exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: address(asset),
                    tokenOut: address(counterAsset),
                    fee: pool.fee(),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: swapParams.counterAssetsShortage,
                    amountInMaximum: swapParams.maxAssetsUseForSwap,
                    sqrtPriceLimitX96: 0
                })
            );
        }
    }

    function _createMintCalldata(int24 lt, int24 ut, uint128 liq) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IDopexV2PositionManager.mintPosition.selector,
                handler,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandler.MintPositionParams({
                        pool: address(pool),
                        tickLower: lt,
                        tickUpper: ut,
                        liquidity: liq
                    })
                )
            );
    }

    function _createBurnCalldata(int24 lt, int24 ut, uint128 shares) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IDopexV2PositionManager.burnPosition.selector,
                handler,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandler.BurnPositionParams({
                        pool: address(pool),
                        tickLower: lt,
                        tickUpper: ut,
                        shares: shares
                    })
                )
            );
    }
}