// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase, max-states-count */

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";

import {ChainlinkQuoter} from "../ChainlinkQuoter.sol";
import {UniswapV3SingleTickLiquidityLibV2} from "../lib/UniswapV3SingleTickLiquidityLibV2.sol";
import {OrangeERC20Upgradeable} from "../OrangeERC20Upgradeable.sol";
import {IERC20Decimals} from "../interfaces/IERC20Extended.sol";

import {IOrangeStrykeLPAutomatorV2} from "./IOrangeStrykeLPAutomatorV2.sol";
import {IOrangeStrykeLPAutomatorState} from "./../interfaces/IOrangeStrykeLPAutomatorState.sol";
import {IOrangeSwapProxy} from "./IOrangeSwapProxy.sol";

import {IBalancerVault} from "./../vendor/balancer/IBalancerVault.sol";

import {BalancerFlashLoanRecipientUpgradeable} from "./../BalancerFlashLoanRecipientUpgradeable.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IMulticallProvider {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

/**
 * @title OrangeStrykeLPAutomatorV1
 * @dev Automate liquidity provision of Stryke CLAMM
 * @author Orange Finance
 */
contract OrangeStrykeLPAutomatorV2 is
    IOrangeStrykeLPAutomatorV2,
    UUPSUpgradeable,
    OrangeERC20Upgradeable,
    BalancerFlashLoanRecipientUpgradeable
{
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using TickMath for int24;
    using UniswapV3SingleTickLiquidityLibV2 for IUniswapV3SingleTickLiquidityHandlerV2;
    using Address for address;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Vault params
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    uint24 private constant _MAX_TICKS = 120;
    /// @notice max deposit fee percentage is 1% (hundredth of 1e6)
    uint24 private constant _MAX_PERF_FEE_PIPS = 10_000;

    IERC20 public asset;
    IERC20 public counterAsset;

    uint256 public minDepositAssets;
    uint256 public depositCap;

    /// @notice deposit fee percentage, hundredths of a bip (1 pip = 0.0001%)
    uint24 public depositFeePips;
    address public depositFeeRecipient;

    mapping(address => bool) public isOwner;
    mapping(address => bool) public isStrategist;

    EnumerableSet.UintSet internal _activeTicks;

    uint8 private _decimals;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Stryke
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IDopexV2PositionManager public manager;
    IUniswapV3SingleTickLiquidityHandlerV2 public handler;
    address public handlerHook;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Chainlink
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    ChainlinkQuoter public quoter;
    address public assetUsdFeed;
    address public counterAssetUsdFeed;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Uniswap
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IUniswapV3Pool public pool;
    /// @dev previously used as Uniswap Router, now used as own router
    address public router;
    int24 public poolTickSpacing;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Balancer
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IBalancerVault public balancer;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Modifiers
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert Unauthorized();
        _;
    }

    modifier onlyStrategist() {
        if (!isStrategist[msg.sender]) revert Unauthorized();
        _;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Upgradeable functions
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Constructor arguments for OrangeDopexV2LPAutomatorV1 contract.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     * @param admin The address of the admin role.
     * @param manager The address of the DopexV2PositionManager contract.
     * @param handler The address of the UniswapV3SingleTickLiquidityHandler contract.
     * @param router The address of the SwapRouter contract.
     * @param pool The address of the UniswapV3Pool contract.
     * @param asset The address of the ERC20 token used as the deposit asset in this vault.
     * @param minDepositAssets The minimum amount of assets that can be deposited.
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
        address assetUsdFeed;
        address counterAssetUsdFeed;
        uint256 minDepositAssets;
        IBalancerVault balancer;
    }

    function initialize(InitArgs memory args) public initializer {
        if (args.asset != IERC20(args.pool.token0()) && args.asset != IERC20(args.pool.token1()))
            revert TokenAddressMismatch();
        if (args.assetUsdFeed == address(0) || args.counterAssetUsdFeed == address(0)) revert AddressZero();

        __ERC20_init(args.name, args.symbol);
        __BalancerFlashLoanRecipient_init(args.balancer);

        _decimals = IERC20Decimals(address(args.asset)).decimals();

        quoter = args.quoter;
        assetUsdFeed = args.assetUsdFeed;
        counterAssetUsdFeed = args.counterAssetUsdFeed;

        manager = args.manager;
        handler = args.handler;
        handlerHook = args.handlerHook;
        pool = args.pool;
        asset = args.asset;
        counterAsset = args.pool.token0() == address(args.asset)
            ? IERC20(args.pool.token1())
            : IERC20(args.pool.token0());
        poolTickSpacing = args.pool.tickSpacing();

        if (_decimals < 3) revert UnsupportedDecimals();
        if (IERC20Decimals(address(counterAsset)).decimals() < 3) revert UnsupportedDecimals();

        // The minimum deposit must be set to greater than 0.1% of the asset's value, otherwise, the transaction will result in zero shares being allocated.
        if (args.minDepositAssets <= (10 ** _decimals / 1000)) revert MinDepositAssetsTooSmall();
        // The minimum deposit should be set to 1e6 (equivalent to 100% in pip units). Failing to do so will result in a zero deposit fee for the recipient.
        if (args.minDepositAssets < 1e6) revert MinDepositAssetsTooSmall();

        minDepositAssets = args.minDepositAssets;

        balancer = args.balancer;

        args.asset.safeIncreaseAllowance(address(args.manager), type(uint256).max);
        counterAsset.safeIncreaseAllowance(address(args.manager), type(uint256).max);

        isOwner[args.admin] = true;
    }

    // only for upgrade
    function initializeV2() external reinitializer(2) {
        __BalancerFlashLoanRecipient_init(balancer);
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    function setOwner(address user, bool approved) external onlyOwner {
        isOwner[user] = approved;
    }

    function setStrategist(address user, bool approved) external onlyOwner {
        isStrategist[user] = approved;
    }

    /**
     * @dev Sets the deposit cap for the automator.
     * @param _depositCap The new deposit cap value.
     * Requirements:
     * - Caller must have the DEFAULT_ADMIN_ROLE.
     */
    function setDepositCap(uint256 _depositCap) external onlyOwner {
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
    function setDepositFeePips(address recipient, uint24 pips) external onlyOwner {
        if (recipient == address(0)) revert AddressZero();
        if (pips > _MAX_PERF_FEE_PIPS) revert FeePipsTooHigh();

        depositFeeRecipient = recipient;
        depositFeePips = pips;

        emit DepositFeePipsSet(pips);
    }

    function setProxyWhitelist(address swapProxy, bool approve) external onlyOwner {
        if (approve) {
            // check if already approved to avoid reusing allowance by the router
            if (asset.allowance(address(this), swapProxy) > 0) revert ProxyAlreadyWhitelisted();
            asset.forceApprove(swapProxy, type(uint256).max);
            counterAsset.forceApprove(swapProxy, type(uint256).max);
        } else {
            asset.forceApprove(swapProxy, 0);
            counterAsset.forceApprove(swapProxy, 0);
        }
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    VAULT STATE DERIVATION FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorState
    function totalAssets() public view returns (uint256) {
        // 1. calculate the total assets in Dopex pools
        uint256 _length = _activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = pool.slot0();

        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(_activeTicks.at(i)));
            _ut = _lt + poolTickSpacing;
            _tid = handler.tokenId(address(pool), handlerHook, _lt, _ut);

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
            quoter.getQuote(
                ChainlinkQuoter.QuoteRequest({
                    baseToken: address(counterAsset),
                    quoteToken: address(asset),
                    baseAmount: _base,
                    baseUsdFeed: counterAssetUsdFeed,
                    quoteUsdFeed: assetUsdFeed
                })
            );
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorState
    function convertToShares(uint256 assets) external view returns (uint256) {
        // NOTE: no need to check total supply as it is checked in deposit function.
        return assets.mulDiv(totalSupply(), totalAssets());
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorState
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply();

        return _supply == 0 ? shares : shares.mulDiv(totalAssets(), _supply);
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorState
    function getActiveTicks() external view returns (int24[] memory) {
        uint256[] memory _tempTicks = _activeTicks.values();
        int24[] memory __activeTicks = new int24[](_tempTicks.length);

        for (uint256 i; i < _tempTicks.length; i++) {
            __activeTicks[i] = int24(uint24(_tempTicks[i]));
        }

        return __activeTicks;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    USER ACTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert AmountZero();
        if (assets < minDepositAssets) revert DepositTooSmall();
        if (assets + totalAssets() > depositCap) revert DepositCapExceeded();

        uint256 _beforeTotalAssets = totalAssets();

        // NOTE: Call transfer on first to avoid reentrancy of ERC777 assets that have hook before transfer.
        // This is a common practice, similar to OpenZeppelin's ERC4626.
        //
        // Reference: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a72c9561b9c200bac87f14ffd43a8c719fd6fa5a/contracts/token/ERC20/extensions/ERC4626.sol#L244

        asset.safeTransferFrom(msg.sender, address(this), assets);

        if (totalSupply() == 0) {
            uint256 _dead;
            // this cannot overflow as we ensure that the decimals is at least 3 in the constructor
            unchecked {
                _dead = 10 ** _decimals / 1000;
            }

            // NOTE: mint small amount of shares to avoid sandwich attack on the first deposit
            // https://mixbytes.io/blog/overview-of-the-inflation-attack
            _mint(address(0), _dead);

            unchecked {
                shares = assets - _dead;
            }
        } else {
            // NOTE: Assets are already transferred before calculation, so we can use the total assets before deposit
            shares = assets.mulDiv(totalSupply(), _beforeTotalAssets);
        }

        uint256 _fee = shares.mulDiv(depositFeePips, 1e6);
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
        bytes calldata redeemData
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares) {
        if (shares == 0) revert AmountZero();
        if (convertToAssets(shares) == 0) revert SharesTooSmall();

        uint256 _tsBeforeBurn = totalSupply();

        // To avoid any reentrancy, we burn the shares first
        _burn(msg.sender, shares);

        uint256 _preAssets = asset.balanceOf(address(this));
        uint256 _preCounter = counterAsset.balanceOf(address(this));

        RedeemLoopCache memory c;
        uint256 _length = _activeTicks.length();

        LockedDopexShares[] memory _tempShares = new LockedDopexShares[](_length);

        for (uint256 i = 0; i < _length; ) {
            c.lowerTick = int24(uint24(_activeTicks.at(i)));

            c.tokenId = handler.tokenId(address(pool), handlerHook, c.lowerTick, c.lowerTick + poolTickSpacing);

            (, uint128 _redeemableLiquidity, uint128 _lockedLiquidity) = handler.positionDetail(
                address(this),
                c.tokenId
            );

            // total supply before burn is used to calculate the precise share
            c.shareRedeemable = uint256(handler.convertToShares(_redeemableLiquidity, c.tokenId)).mulDiv(
                shares,
                _tsBeforeBurn
            );
            c.shareLocked = uint256(handler.convertToShares(_lockedLiquidity, c.tokenId)).mulDiv(shares, _tsBeforeBurn);

            // locked share is transferred to the user
            if (c.shareLocked > 0) {
                unchecked {
                    _tempShares[c.lockedShareIndex++] = LockedDopexShares({tokenId: c.tokenId, shares: c.shareLocked});
                }

                handler.transfer(msg.sender, c.tokenId, c.shareLocked);
            }

            // redeemable share is burned
            if (c.shareRedeemable > 0)
                if (handler.paused()) {
                    handler.transfer(msg.sender, c.tokenId, c.shareRedeemable);
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

        uint256 _pay = shares.mulDiv(_preCounter, _tsBeforeBurn) + counterAsset.balanceOf(address(this)) - _preCounter;

        if (_pay > 0) {
            (address _swapProxy, address _swapProvider, bytes memory _swapCalldata) = abi.decode(
                redeemData,
                (address, address, bytes)
            );

            if (asset.allowance(address(this), _swapProxy) == 0) revert Unauthorized();

            IOrangeSwapProxy(_swapProxy).swapInput(
                IOrangeSwapProxy.SwapInputRequest({
                    provider: _swapProvider,
                    swapCalldata: _swapCalldata,
                    expectTokenIn: asset,
                    expectTokenOut: counterAsset,
                    expectAmountIn: _pay,
                    inputDelta: 10 // 0.01% slippage
                })
            );
        }

        // solhint-disable-next-line reentrancy
        assets = shares.mulDiv(_preAssets, _tsBeforeBurn) + asset.balanceOf(address(this)) - _preAssets;

        asset.safeTransfer(msg.sender, assets);

        emit Redeem(msg.sender, shares, assets);
    }

    function _burnPosition(int24 lowerTick, int24 upperTick, uint128 shares) internal {
        manager.burnPosition(
            handler,
            abi.encode(
                IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                    pool: address(pool),
                    hook: handlerHook,
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
    function withdraw(IERC20 token) external onlyOwner {
        if (token == asset) revert TokenNotPermitted();
        if (token == counterAsset) revert TokenNotPermitted();
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    STRATEGIST ACTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorV2
    function rebalance(
        RebalanceTick[] calldata ticksMint,
        RebalanceTick[] calldata ticksBurn,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest calldata swapRequest,
        bytes calldata flashLoanData
    ) external onlyStrategist {
        // prepare the calldata for multicall
        bytes[] memory _burnCalldataBatch = _createBurnCalldataBatch(ticksBurn);
        bytes[] memory _mintCalldataBatch = _createMintCalldataBatch(ticksMint);

        (IERC20[] memory _tokens, uint256[] memory _amounts, bool _execFlashLoan) = abi.decode(
            flashLoanData,
            (IERC20[], uint256[], bool)
        );

        // prepare flash loan request
        FlashLoanUserData memory _userData = FlashLoanUserData({
            swapProxy: swapProxy,
            swapRequest: swapRequest,
            mintCalldata: _mintCalldataBatch,
            burnCalldata: _burnCalldataBatch
        });

        // execute flash loan, then _onFlashLoanReceived will call the multicall
        if (_execFlashLoan) _makeFlashLoan(_tokens, _amounts, abi.encode(_userData));

        if (ticksMint.length + _activeTicks.length() > _MAX_TICKS) revert MaxTicksReached();

        emit Rebalance(msg.sender, ticksMint, ticksBurn);
    }

    function _onFlashLoanReceived(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) internal override {
        FlashLoanUserData memory _ud = abi.decode(userData, (FlashLoanUserData));

        // NOTE: burn should be called before mint to receive the assets from the burned position
        if (_ud.burnCalldata.length > 0) IMulticallProvider(address(manager)).multicall(_ud.burnCalldata);
        if (_ud.mintCalldata.length > 0) IMulticallProvider(address(manager)).multicall(_ud.mintCalldata);

        // we can directly pass the request as the user data is provided by the trusted strategist
        IOrangeSwapProxy(_ud.swapProxy).swapInput(_ud.swapRequest);

        // repay flash loan
        for (uint256 i = 0; i < tokens.length; ) {
            tokens[i].safeTransfer(msg.sender, amounts[i] + feeAmounts[i]);

            unchecked {
                i++;
            }
        }
    }

    function _createMintCalldataBatch(
        RebalanceTick[] calldata ticksMint
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
            _ut = _lt + poolTickSpacing;

            mintCalldataBatch[j] = _createMintCalldata(_lt, _ut, ticksMint[i].liquidity);

            // If the position is not active, push it to the active ticks
            _tid = handler.tokenId(address(pool), handlerHook, _lt, _ut);
            if (handler.balanceOf(address(this), _tid) == 0) _activeTicks.add(uint256(uint24(_lt)));

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
        RebalanceTick[] calldata ticksMint
    ) internal view returns (uint256 mintLength, uint256 ignoreIndex) {
        uint256 _providedLength = ticksMint.length;
        mintLength = _providedLength;

        (, int24 _ct, , , , , ) = pool.slot0();
        int24 _spacing = poolTickSpacing;

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
        RebalanceTick[] calldata ticksBurn
    ) internal returns (bytes[] memory burnCalldataBatch) {
        int24 _lt;
        int24 _ut;
        uint256 _tid;
        uint256 _shares;
        uint256 _burnLength = ticksBurn.length;
        burnCalldataBatch = new bytes[](_burnLength);
        for (uint256 i = 0; i < _burnLength; ) {
            _lt = ticksBurn[i].tick;
            _ut = _lt + poolTickSpacing;

            _tid = _tid = handler.tokenId(address(pool), handlerHook, _lt, _ut);
            _shares = handler.convertToShares(ticksBurn[i].liquidity, _tid);
            burnCalldataBatch[i] = _createBurnCalldata(_lt, _ut, _shares.toUint128());

            // if all shares will be burned, pop the active tick
            if (handler.balanceOf(address(this), _tid) - _shares == 0) _activeTicks.remove(uint256(uint24(_lt)));

            unchecked {
                i++;
            }
        }
    }

    function _createMintCalldata(int24 lt, int24 ut, uint128 liq) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IDopexV2PositionManager.mintPosition.selector,
                handler,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                        pool: address(pool),
                        hook: handlerHook,
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
                    IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                        pool: address(pool),
                        hook: handlerHook,
                        tickLower: lt,
                        tickUpper: ut,
                        shares: shares
                    })
                )
            );
    }
}
