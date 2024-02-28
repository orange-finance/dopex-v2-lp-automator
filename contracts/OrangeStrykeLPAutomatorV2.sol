// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IOrangeStrykeLPAutomatorV2} from "./interfaces/IOrangeStrykeLPAutomatorV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {ChainlinkQuoter} from "./ChainlinkQuoter.sol";
import {BalancerFlashLoanRecipient} from "./BalancerFlashLoanRecipient.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLib} from "./lib/UniswapV3SingleTickLiquidityLib.sol";
import {UniswapV3PoolLib} from "./lib/UniswapV3PoolLib.sol";
import {IDopexV2PositionManager} from "./vendor/dopexV2/IDopexV2PositionManager.sol";
import {IBalancerVault} from "./vendor/BALANCER/IBalancerVault.sol";

import {IERC20Decimals} from "./interfaces/IERC20Extended.sol";

interface IMulticallProvider {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

/**
 * @title OrangeStrykeLPAutomatorV2
 * @dev Automate liquidity provision for Stryke(formerly Dopex) contract
 * @author Orange Finance
 */
contract OrangeStrykeLPAutomatorV2 is
    IOrangeStrykeLPAutomatorV2,
    ERC20,
    AccessControlEnumerable,
    BalancerFlashLoanRecipient
{
    using FixedPointMathLib for uint256;
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using TickMath for int24;
    using UniswapV3PoolLib for IUniswapV3Pool;
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                VAULT STATES
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    /// @notice automator's deposit ASSET
    IERC20 public immutable ASSET;
    /// @notice the counter ASSET of uniswap v3 POOL
    IERC20 public immutable COUNTER_ASSET;
    /// @notice the maximum number of ticks that can be managed by the automator
    uint24 private constant MAX_TICKS = 120;
    /// @notice max deposit fee percentage is 1% (hundredth of 1e6)
    uint24 private constant MAX_PERF_FEE_PIPS = 10_000;
    /// @notice the minimum amount of assets that can be deposited
    uint256 public immutable MIN_DEPOSIT_ASSETS;
    /// @notice the total deposit cap for the automator
    uint256 public depositCap;
    /// @notice deposit fee percentage, hundredths of a bip (1 pip = 0.0001%)
    uint24 public depositFeePips;
    /// @notice the address of the recipient of the deposit fee
    address public depositFeeRecipient;
    /// @notice the uniswap v3 POOL ticks that currently have liquidity
    EnumerableSet.UintSet private activeTicks;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                            CHAINLINK STATES
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    ChainlinkQuoter public immutable QUOTER;
    address public immutable ASSET_USD_FEED;
    address public immutable COUNTER_ASSET_USD_FEED;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                            UNISWAP V3 STATES
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IUniswapV3Pool public immutable POOL;
    int24 public immutable POOL_TICK_SPACING;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                            DOPEX STATES
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IDopexV2PositionManager public immutable MANAGER;
    IUniswapV3SingleTickLiquidityHandlerV2 public immutable HANDLER;
    address public immutable HANDLER_HOOK;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                            BALANCER STATES
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IBalancerVault public immutable BALANCER;

    event Deposit(address indexed sender, uint256 assets, uint256 sharesMinted);
    event Redeem(address indexed sender, uint256 shares, uint256 assetsWithdrawn);
    event Rebalance(address indexed sender, RebalanceTickInfo[] ticksMint, RebalanceTickInfo[] ticksBurn);

    event DepositCapSet(uint256 depositCap);
    event DepositFeePipsSet(uint24 depositFeePips);

    error AddressZero();
    error AmountZero();
    error MaxTicksReached();
    error InvalidRebalanceParams();
    error MinAssetsRequired(uint256 minAssets, uint256 actualAssets);
    error TokenAddressMismatch();
    error TokenNotPermitted();
    error DepositTooSmall();
    error DepositCapExceeded();
    error SharesTooSmall();
    error FeePipsTooHigh();
    error UnsupportedDecimals();
    error MinDepositAssetsTooSmall();

    /**
     * @dev Constructor arguments for OrangeDopexV2LPAutomator contract.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     * @param admin The address of the admin role.
     * @param MANAGER The address of the DopexV2PositionManager contract.
     * @param HANDLER The address of the UniswapV3SingleTickLiquidityHandler contract.
     * @param POOL The address of the UniswapV3Pool contract.
     * @param ASSET The address of the ERC20 token used as the deposit ASSET in this vault.
     * @param MIN_DEPOSIT_ASSETS The minimum amount of assets that can be deposited.
     */
    struct InitArgs {
        string name;
        string symbol;
        address admin;
        IDopexV2PositionManager manager;
        IUniswapV3SingleTickLiquidityHandlerV2 handler;
        address handlerHook;
        IUniswapV3Pool pool;
        IERC20 asset;
        ChainlinkQuoter quoter;
        IBalancerVault balancer;
        address assetUsdFeed;
        address counterAssetUsdFeed;
        uint256 minDepositAssets;
    }

    constructor(InitArgs memory args) ERC20(args.name, args.symbol, IERC20Decimals(address(args.asset)).decimals()) {
        if (args.asset != IERC20(args.pool.token0()) && args.asset != IERC20(args.pool.token1()))
            revert TokenAddressMismatch();
        if (args.assetUsdFeed == address(0) || args.counterAssetUsdFeed == address(0)) revert AddressZero();

        QUOTER = args.quoter;
        ASSET_USD_FEED = args.assetUsdFeed;
        COUNTER_ASSET_USD_FEED = args.counterAssetUsdFeed;
        MANAGER = args.manager;
        HANDLER = args.handler;
        HANDLER_HOOK = args.handlerHook;
        BALANCER = args.balancer;
        POOL = args.pool;
        ASSET = args.asset;
        COUNTER_ASSET = args.pool.token0() == address(args.asset)
            ? IERC20(args.pool.token1())
            : IERC20(args.pool.token0());
        POOL_TICK_SPACING = args.pool.tickSpacing();

        if (IERC20Decimals(address(args.asset)).decimals() < 3) revert UnsupportedDecimals();
        if (IERC20Decimals(address(COUNTER_ASSET)).decimals() < 3) revert UnsupportedDecimals();

        // The minimum deposit must be set to greater than 0.1% of the ASSET's value, otherwise, the transaction will result in zero shares being allocated.
        if (args.minDepositAssets <= (10 ** IERC20Decimals(address(args.asset)).decimals() / 1000))
            revert MinDepositAssetsTooSmall();
        // The minimum deposit should be set to 1e6 (equivalent to 100% in pip units). Failing to do so will result in a zero deposit fee for the recipient.
        if (args.minDepositAssets < 1e6) revert MinDepositAssetsTooSmall();

        MIN_DEPOSIT_ASSETS = args.minDepositAssets;

        args.asset.safeIncreaseAllowance(address(args.manager), type(uint256).max);

        COUNTER_ASSET.safeIncreaseAllowance(address(args.manager), type(uint256).max);

        _grantRole(DEFAULT_ADMIN_ROLE, args.admin);
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

        emit DepositCapSet(_depositCap);
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

        emit DepositFeePipsSet(pips);
    }

    function setRouterWhitelist(address router, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ASSET.approve(router, 0);
        COUNTER_ASSET.approve(router, 0);

        if (status) {
            ASSET.approve(router, type(uint256).max);
            COUNTER_ASSET.approve(router, type(uint256).max);
        } else {
            COUNTER_ASSET.safeApprove(router, 0);
        }
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    VAULT STATE DERIVATION FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function getAutomatorPositions()
        external
        view
        returns (uint256 balanceDepositAsset, uint256 balanceCounterAsset, RebalanceTickInfo[] memory ticks)
    {
        int24 _spacing = POOL_TICK_SPACING;

        // 1. calculate the total assets in Dopex pools
        uint256 _length = activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);

        ticks = new RebalanceTickInfo[](_length);

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(activeTicks.at(i)));
            _ut = _lt + _spacing;
            _tid = HANDLER.tokenId(address(POOL), HANDLER_HOOK, _lt, _ut);

            _liquidity = HANDLER.convertToAssets((HANDLER.balanceOf(address(this), _tid)).toUint128(), _tid);

            ticks[i] = RebalanceTickInfo({tick: _lt, liquidity: _liquidity});

            unchecked {
                i++;
            }
        }

        return (ASSET.balanceOf(address(this)), COUNTER_ASSET.balanceOf(address(this)), ticks);
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function totalAssets() public view returns (uint256) {
        // 1. calculate the total assets in Dopex pools
        uint256 _length = activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = POOL.slot0();

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(activeTicks.at(i)));
            _ut = _lt + POOL_TICK_SPACING;
            _tid = HANDLER.tokenId(address(POOL), HANDLER_HOOK, _lt, _ut);

            _liquidity = HANDLER.convertToAssets((HANDLER.balanceOf(address(this), _tid)).toUint128(), _tid);

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
        (uint256 _base, uint256 _quote) = (COUNTER_ASSET.balanceOf(address(this)), ASSET.balanceOf(address(this)));

        if (address(ASSET) == POOL.token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            QUOTER.getQuote(
                ChainlinkQuoter.QuoteRequest({
                    baseToken: address(COUNTER_ASSET),
                    quoteToken: address(ASSET),
                    baseAmount: _base,
                    baseUsdFeed: COUNTER_ASSET_USD_FEED,
                    quoteUsdFeed: ASSET_USD_FEED
                })
            );
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function freeAssets() public view returns (uint256) {
        // 1. calculate the free assets in Dopex pools
        uint256 _length = activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = POOL.slot0();

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(activeTicks.at(i)));
            _ut = _lt + POOL_TICK_SPACING;
            _tid = HANDLER.tokenId(address(POOL), HANDLER_HOOK, _lt, _ut);

            _liquidity = HANDLER.redeemableLiquidity(address(this), _tid).toUint128();

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
        (uint256 _base, uint256 _quote) = (COUNTER_ASSET.balanceOf(address(this)), ASSET.balanceOf(address(this)));

        if (address(ASSET) == POOL.token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            QUOTER.getQuote(
                ChainlinkQuoter.QuoteRequest({
                    baseToken: address(COUNTER_ASSET),
                    quoteToken: address(ASSET),
                    baseAmount: _base,
                    baseUsdFeed: COUNTER_ASSET_USD_FEED,
                    quoteUsdFeed: ASSET_USD_FEED
                })
            );
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function convertToShares(uint256 assets) external view returns (uint256) {
        // NOTE: no need to check total supply as it is checked in deposit function.
        return assets.mulDivDown(totalSupply, totalAssets());
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply;

        return _supply == 0 ? shares : shares.mulDivDown(totalAssets(), _supply);
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function getTickAllLiquidity(int24 tick) external view returns (uint128) {
        uint256 _share = HANDLER.balanceOf(
            address(this),
            HANDLER.tokenId(address(POOL), HANDLER_HOOK, tick, tick + POOL_TICK_SPACING)
        );

        if (_share == 0) return 0;

        return
            HANDLER.convertToAssets(
                _share.toUint128(),
                HANDLER.tokenId(address(POOL), HANDLER_HOOK, tick, tick + POOL_TICK_SPACING)
            );
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function getTickFreeLiquidity(int24 tick) external view returns (uint128) {
        return
            HANDLER
                .redeemableLiquidity(
                    address(this),
                    HANDLER.tokenId(address(POOL), HANDLER_HOOK, tick, tick + POOL_TICK_SPACING)
                )
                .toUint128();
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
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

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert AmountZero();
        if (assets < MIN_DEPOSIT_ASSETS) revert DepositTooSmall();
        if (assets + totalAssets() > depositCap) revert DepositCapExceeded();

        uint256 _beforeTotalAssets = totalAssets();

        // NOTE: Call transfer on first to avoid reentrancy of ERC777 assets that have hook before transfer.
        // This is a common practice, similar to OpenZeppelin's ERC4626.
        //
        // Reference: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a72c9561b9c200bac87f14ffd43a8c719fd6fa5a/contracts/token/ERC20/extensions/ERC4626.sol#L244

        ASSET.safeTransferFrom(msg.sender, address(this), assets);

        if (totalSupply == 0) {
            uint256 _dead;
            // this cannot overflow as we ensure that the decimals is at least 3 in the constructor
            unchecked {
                _dead = 10 ** decimals / 1000;
            }

            // NOTE: mint small amount of shares to avoid sandwich attack on the first deposit
            // https://mixbytes.io/blog/overview-of-the-inflation-attack
            _mint(address(0), _dead);

            unchecked {
                shares = assets - _dead;
            }
        } else {
            // NOTE: Assets are already transferred before calculation, so we can use the total assets before deposit
            shares = assets.mulDivDown(totalSupply, _beforeTotalAssets);
        }

        uint256 _fee = shares.mulDivDown(depositFeePips, 1e6);
        // NOTE: no possibility of minting to the zero address as we can't set zero address with fee pips
        if (_fee > 0) {
            _mint(depositFeeRecipient, _fee);
            shares = shares - _fee;
        }

        if (shares == 0) revert DepositTooSmall();
        _mint(msg.sender, shares);

        emit Deposit(msg.sender, assets, shares);
    }

    /// @dev avoid stack too deep error
    struct RedeemLoopCache {
        int24 lowerTick;
        uint256 tokenId;
        uint256 shareLocked;
        uint256 shareRedeemable;
        uint256 lockedShareIndex;
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function redeem(
        uint256 shares,
        uint256 minAssets
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares) {
        if (shares == 0) revert AmountZero();
        if (convertToAssets(shares) == 0) revert SharesTooSmall();

        uint256 _tsBeforeBurn = totalSupply;

        // To avoid any reentrancy, we burn the shares first
        _burn(msg.sender, shares);

        uint256 _preBase = COUNTER_ASSET.balanceOf(address(this));
        uint256 _preQuote = ASSET.balanceOf(address(this));

        RedeemLoopCache memory c;
        uint256 _length = activeTicks.length();

        LockedDopexShares[] memory _tempShares = new LockedDopexShares[](_length);

        for (uint256 i = 0; i < _length; ) {
            c.lowerTick = int24(uint24(activeTicks.at(i)));

            c.tokenId = HANDLER.tokenId(address(POOL), HANDLER_HOOK, c.lowerTick, c.lowerTick + POOL_TICK_SPACING);

            // total supply before burn is used to calculate the precise share
            c.shareRedeemable = uint256(
                HANDLER.convertToShares(HANDLER.redeemableLiquidity(address(this), c.tokenId).toUint128(), c.tokenId)
            ).mulDivDown(shares, _tsBeforeBurn);
            c.shareLocked = uint256(
                HANDLER.convertToShares(HANDLER.lockedLiquidity(address(this), c.tokenId).toUint128(), c.tokenId)
            ).mulDivDown(shares, _tsBeforeBurn);

            // locked share is transferred to the user
            if (c.shareLocked > 0) {
                unchecked {
                    _tempShares[c.lockedShareIndex++] = LockedDopexShares({tokenId: c.tokenId, shares: c.shareLocked});
                }

                HANDLER.transfer(msg.sender, c.tokenId, c.shareLocked);
            }

            // redeemable share is burned
            if (c.shareRedeemable > 0)
                if (HANDLER.paused()) {
                    HANDLER.transfer(msg.sender, c.tokenId, c.shareRedeemable);
                } else {
                    _burnPosition(c.lowerTick, c.lowerTick + POOL_TICK_SPACING, c.shareRedeemable.toUint128());
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
         * 1. shares.mulDivDown(_preBase, _totalSupply) means the portion of idle base ASSET
         * 2. COUNTER_ASSET.balanceOf(address(this)) - _preBase means the base ASSET from redeemed positions
         */
        uint256 _payBase = shares.mulDivDown(_preBase, _tsBeforeBurn) +
            COUNTER_ASSET.balanceOf(address(this)) -
            _preBase;

        // TODO: support swap with aggregator
        // if (_payBase > 0) _swapToRedeemAssets(_payBase);

        assets = shares.mulDivDown(_preQuote, _tsBeforeBurn) + ASSET.balanceOf(address(this)) - _preQuote;

        if (assets < minAssets) revert MinAssetsRequired(minAssets, assets);

        ASSET.safeTransfer(msg.sender, assets);

        emit Redeem(msg.sender, shares, assets);
    }

    function _burnPosition(int24 lowerTick, int24 upperTick, uint128 shares) internal {
        MANAGER.burnPosition(
            HANDLER,
            abi.encode(
                IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                    pool: address(POOL),
                    hook: HANDLER_HOOK,
                    tickLower: lowerTick,
                    tickUpper: upperTick,
                    shares: shares
                })
            )
        );
    }

    /**
     * @dev withdraw pooled assets from the automator. This is used when the automator is rewarded by protocols with another token to prevent lock up.
     * @param token The address of the ERC20 token to withdraw.
     */
    function withdraw(IERC20 token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == ASSET) revert TokenNotPermitted();
        if (token == COUNTER_ASSET) revert TokenNotPermitted();
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    STRATEGIST ACTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function rebalance(
        RebalanceTickInfo[] calldata ticksMint,
        RebalanceTickInfo[] calldata ticksBurn,
        address swapRouter,
        bytes calldata swapCalldata
    ) external onlyRole(STRATEGIST_ROLE) {
        if (ticksMint.length + activeTicks.length() > MAX_TICKS) revert MaxTicksReached();

        bytes[] memory _burnCalldataBatch = _createBurnCalldataBatch(ticksBurn);
        // NOTE: burn should be called before mint to receive the assets from the burned position
        if (_burnCalldataBatch.length > 0) IMulticallProvider(address(MANAGER)).multicall(_burnCalldataBatch);

        bytes[] memory _mintCalldataBatch = _createMintCalldataBatch(ticksMint);

        if (_mintCalldataBatch.length > 0) IMulticallProvider(address(MANAGER)).multicall(_mintCalldataBatch);

        // swap to repay assets
        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, bytes memory data) = swapRouter.call(swapCalldata);

        if (!ok)
            // solhint-disable-next-line no-inline-assembly
            assembly {
                revert(add(data, 32), mload(data))
            }

        emit Rebalance(msg.sender, ticksMint, ticksBurn);
    }

    function _createMintCalldataBatch(
        RebalanceTickInfo[] calldata ticksMint
    ) internal returns (bytes[] memory mintCalldataBatch) {
        (uint256 _actualMintLen, uint256 ignoreIndex) = _getSafeMintParams(ticksMint);
        mintCalldataBatch = new bytes[](_actualMintLen);

        int24 _lt;
        int24 _ut;
        uint256 _tid;
        uint256 j;
        for (uint256 i = 0; i < ticksMint.length; ) {
            if (i == ignoreIndex) {
                unchecked {
                    i++;
                }
                continue;
            }

            _lt = ticksMint[i].tick;
            _ut = _lt + POOL_TICK_SPACING;

            mintCalldataBatch[j] = _createMintCalldata(_lt, _ut, ticksMint[i].liquidity);

            // If the position is not active, push it to the active ticks
            _tid = HANDLER.tokenId(address(POOL), HANDLER_HOOK, _lt, _ut);
            if (HANDLER.balanceOf(address(this), _tid) == 0) activeTicks.add(uint256(uint24(_lt)));

            unchecked {
                i++;
                j++;
            }
        }
    }

    // NOTE: skip current tick as it is not allowed to mint on Dopex
    /**
     * @dev Returns the length of the ticksMint array after skipping the current tick if it is included.
     *      Also returns the index of the current tick in the ticksMint array if it is included.
     *      We need to avoid revert when mint Dopex position in the current tick.
     *      This should be done on automator because current tick got on caller (this must be off-chain) is different from the current tick got on automator.
     * @param ticksMint An array of RebalanceTickInfo structs representing the ticks to mint.
     */
    function _getSafeMintParams(
        RebalanceTickInfo[] calldata ticksMint
    ) internal view returns (uint256 mintLength, uint256 ignoreIndex) {
        uint256 _providedLength = ticksMint.length;
        mintLength = _providedLength;

        int24 _ct = POOL.currentTick();
        int24 _spacing = POOL_TICK_SPACING;

        // current lower tick is calculated by rounding down the current tick to the nearest tick spacing
        // if current tick is negative and not divisible by tick spacing, we need to subtract one tick spacing to get the correct lower tick
        int24 _currentLt = _ct < 0 && _ct % _spacing != 0
            ? (_ct / _spacing - 1) * _spacing
            : (_ct / _spacing) * _spacing;

        for (uint256 i = 0; i < _providedLength; ) {
            if (ticksMint[i].tick == _currentLt) {
                unchecked {
                    mintLength--;
                    ignoreIndex = i;
                    break;
                }
            }
            unchecked {
                i++;
            }
        }

        if (mintLength == _providedLength) ignoreIndex = type(uint256).max;
    }

    function _createBurnCalldataBatch(
        RebalanceTickInfo[] calldata ticksBurn
    ) internal returns (bytes[] memory burnCalldataBatch) {
        int24 _lt;
        int24 _ut;
        uint256 _tid;
        uint256 _shares;
        uint256 _burnLength = ticksBurn.length;
        burnCalldataBatch = new bytes[](_burnLength);
        for (uint256 i = 0; i < _burnLength; ) {
            _lt = ticksBurn[i].tick;
            _ut = _lt + POOL_TICK_SPACING;

            _tid = _tid = HANDLER.tokenId(address(POOL), HANDLER_HOOK, _lt, _ut);
            _shares = HANDLER.convertToShares(ticksBurn[i].liquidity, _tid);
            burnCalldataBatch[i] = _createBurnCalldata(_lt, _ut, _shares.toUint128());

            // if all shares will be burned, pop the active tick
            if (HANDLER.balanceOf(address(this), _tid) - _shares == 0) activeTicks.remove(uint256(uint24(_lt)));

            unchecked {
                i++;
            }
        }
    }

    function _createMintCalldata(int24 lt, int24 ut, uint128 liq) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IDopexV2PositionManager.mintPosition.selector,
                HANDLER,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                        pool: address(POOL),
                        hook: HANDLER_HOOK,
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
                HANDLER,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                        pool: address(POOL),
                        hook: HANDLER_HOOK,
                        tickLower: lt,
                        tickUpper: ut,
                        shares: shares
                    })
                )
            );
    }
}
