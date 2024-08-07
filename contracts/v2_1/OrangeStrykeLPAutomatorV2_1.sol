// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

/* solhint-disable contract-name-camelcase, max-states-count, func-name-mixedcase */

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUniswapV3SingleTickLiquidityHandlerV2} from "../vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IDopexV2PositionManager} from "../vendor/dopexV2/IDopexV2PositionManager.sol";

import {IOrangeQuoter} from "./../interfaces/IOrangeQuoter.sol";
import {UniswapV3SingleTickLiquidityLibV3} from "../lib/UniswapV3SingleTickLiquidityLibV3.sol";
import {OrangeERC20Upgradeable} from "../OrangeERC20Upgradeable.sol";

import {IOrangeStrykeLPAutomatorV2_1} from "./IOrangeStrykeLPAutomatorV2_1.sol";
import {IOrangeSwapProxy} from "../swap-proxy/IOrangeSwapProxy.sol";
import {IUniswapV3PoolAdapter} from "../pool-adapter/IUniswapV3PoolAdapter.sol";

import {IBalancerVault} from "../vendor/balancer/IBalancerVault.sol";
import {IBalancerFlashLoanRecipient} from "../vendor/balancer/IBalancerFlashLoanRecipient.sol";

/**
 * @title OrangeStrykeLPAutomatorV2
 * @dev Automate liquidity provision to Stryke CLAMM
 * @dev v1, v2 initializers are removed because of the contract size limit. You need to deploy(upgrade) v2 contract, then call initializeV2_1 to upgrade to v2.1
 * @author Orange Finance
 */
contract OrangeStrykeLPAutomatorV2_1 is
    IOrangeStrykeLPAutomatorV2_1,
    IBalancerFlashLoanRecipient,
    UUPSUpgradeable,
    OrangeERC20Upgradeable
{
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using TickMath for int24;
    using UniswapV3SingleTickLiquidityLibV3 for IUniswapV3SingleTickLiquidityHandlerV2;
    using Address for address;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Vault params
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    uint24 private constant _MAX_TICKS = 150;
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
    IOrangeQuoter public quoter;
    address public assetUsdFeed;
    address public counterAssetUsdFeed;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Uniswap
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    ///@custom:oz-renamed-from pool
    IUniswapV3Pool internal _pool;
    ISwapRouter public router;
    int24 public poolTickSpacing;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    V2 States
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IBalancerVault public balancer;
    bytes32 private _flashLoanHash;
    /// @dev this parameter is no longer used in v2.1. redeem function simply uses the SwapRouter, and rebalance function's delta is set off-chain by strategist
    uint256 public swapInputDelta;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    V2_1 States
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    IUniswapV3PoolAdapter public poolAdapter;

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

    modifier validateFlashLoan(bytes memory userData) {
        // check if flash loan request is made by this contract
        bytes32 _givenHash = keccak256(userData);
        if (_flashLoanHash == bytes32(0) || _flashLoanHash != _givenHash) revert FlashLoan_Unauthorized();

        // clear hash to avoid reentrancy
        _flashLoanHash = bytes32(0);
        _;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Upgradeable functions
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // @inheritdoc UUPSUpgradeable
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev used for upgrade from v2 to v2.1. This is a one-time operation.
     */
    function initializeV2_1(IUniswapV3PoolAdapter adapter_) external reinitializer(3) onlyOwner {
        poolAdapter = adapter_;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Sets the owner of the automator.
     * @param user The address of the user.
     * @param approved The approval status of the user.
     */
    function setOwner(address user, bool approved) external onlyOwner {
        isOwner[user] = approved;

        emit SetOwner(user, approved);
    }

    /**
     * @dev Sets the strategist of the automator.
     * @param user The address of the user.
     * @param approved The approval status of the user.
     */
    function setStrategist(address user, bool approved) external onlyOwner {
        isStrategist[user] = approved;

        emit SetStrategist(user, approved);
    }

    /**
     * @dev Sets the deposit cap for the automator.
     * @param _depositCap The new deposit cap value.
     */
    function setDepositCap(uint256 _depositCap) external onlyOwner {
        depositCap = _depositCap;

        emit SetDepositCap(_depositCap);
    }

    /**
     * @dev Sets the deposit fee pips for a recipient.
     * @param recipient The address of the recipient.
     * @param pips The new deposit fee pips value.
     */
    function setDepositFeePips(address recipient, uint24 pips) external onlyOwner {
        if (recipient == address(0)) revert AddressZero();
        if (pips > _MAX_PERF_FEE_PIPS) revert FeePipsTooHigh();

        depositFeeRecipient = recipient;
        depositFeePips = pips;

        emit SetDepositFeePips(pips);
    }

    /**
     * @dev Sets the proxy whitelist for the automator.
     * @param swapProxy The address of the swap proxy.
     * @param approve The approval status of the swap proxy.
     */
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

        emit SetProxyWhitelist(swapProxy, approve);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    VAULT STATE DERIVATION FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
    function pool() public view returns (address) {
        return poolAdapter.pool();
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
    function totalAssets() public view returns (uint256) {
        // 1. calculate the total assets in Dopex pools
        uint256 _length = _activeTicks.length();
        uint256 _tid;
        uint128 _liquidity;
        (int24 _lt, int24 _ut) = (0, 0);
        (uint256 _sum0, uint256 _sum1) = (0, 0);
        (uint256 _a0, uint256 _a1) = (0, 0);
        (uint256 _fee0, uint256 _fee1) = (0, 0);

        (uint160 _sqrtRatioX96, , , , , , ) = poolAdapter.slot0();

        // convert all positions and swap fees to assets
        for (uint256 i = 0; i < _length; ) {
            _lt = int24(uint24(_activeTicks.at(i)));
            _ut = _lt + poolTickSpacing;
            _tid = handler.tokenId(poolAdapter.pool(), handlerHook, _lt, _ut);

            (_liquidity, , , _fee0, _fee1) = UniswapV3SingleTickLiquidityLibV3.positionDetail(
                UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                    handler: handler,
                    pool: poolAdapter.pool(),
                    hook: handlerHook,
                    tickLower: _lt,
                    tickUpper: _ut,
                    owner: address(this)
                })
            );

            (_a0, _a1) = LiquidityAmounts.getAmountsForLiquidity(
                _sqrtRatioX96,
                _lt.getSqrtRatioAtTick(),
                _ut.getSqrtRatioAtTick(),
                _liquidity
            );

            _sum0 += (_a0 + _fee0);
            _sum1 += (_a1 + _fee1);

            unchecked {
                i++;
            }
        }

        // 2. merge into the total assets in the automator
        (uint256 _base, uint256 _quote) = (counterAsset.balanceOf(address(this)), asset.balanceOf(address(this)));

        if (address(asset) == poolAdapter.token0()) {
            _base += _sum1;
            _quote += _sum0;
        } else {
            _base += _sum0;
            _quote += _sum1;
        }

        return
            _quote +
            quoter.getQuote(
                IOrangeQuoter.QuoteRequest({
                    baseToken: address(counterAsset),
                    quoteToken: address(asset),
                    baseAmount: _base,
                    baseUsdFeed: counterAssetUsdFeed,
                    quoteUsdFeed: assetUsdFeed
                })
            );
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
    function convertToShares(uint256 assets) external view returns (uint256) {
        // NOTE: no need to check total supply as it is checked in deposit function.
        return assets.mulDiv(totalSupply(), totalAssets());
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply();

        return _supply == 0 ? shares : shares.mulDiv(totalAssets(), _supply);
    }

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
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

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
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

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
    function redeem(
        uint256 shares,
        uint256 minAssets
    ) external returns (uint256 assets, LockedDopexShares[] memory lockedDopexShares) {
        if (shares == 0) revert AmountZero();
        if (convertToAssets(shares) == 0) revert SharesTooSmall();

        uint256 _tsBeforeBurn = totalSupply();

        // To avoid any reentrancy, we burn the shares first
        _burn(msg.sender, shares);

        uint256 _preBase = counterAsset.balanceOf(address(this));
        uint256 _preQuote = asset.balanceOf(address(this));

        RedeemLoopCache memory c;
        uint256 _length = _activeTicks.length();

        LockedDopexShares[] memory _tempShares = new LockedDopexShares[](_length);

        for (uint256 i = 0; i < _length; ) {
            c.lowerTick = int24(uint24(_activeTicks.at(i)));

            c.tokenId = handler.tokenId(poolAdapter.pool(), handlerHook, c.lowerTick, c.lowerTick + poolTickSpacing);

            (, uint128 _redeemableLiquidity, uint128 _lockedLiquidity, , ) = UniswapV3SingleTickLiquidityLibV3
                .positionDetail(
                    UniswapV3SingleTickLiquidityLibV3.PositionDetailParams({
                        handler: handler,
                        pool: poolAdapter.pool(),
                        hook: handlerHook,
                        tickLower: c.lowerTick,
                        tickUpper: c.lowerTick + poolTickSpacing,
                        owner: address(this)
                    })
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

        /**
         * 1. shares.mulDiv(_preBase, _totalSupply()) means the portion of idle base asset
         * 2. counterAsset.balanceOf(address(this)) - _preBase means the base asset from redeemed positions
         */
        uint256 _payBase = shares.mulDiv(_preBase, _tsBeforeBurn) + counterAsset.balanceOf(address(this)) - _preBase;

        if (_payBase > 0) _swapToRedeemAssets(_payBase);

        // solhint-disable-next-line reentrancy
        assets = shares.mulDiv(_preQuote, _tsBeforeBurn) + asset.balanceOf(address(this)) - _preQuote;

        if (assets < minAssets) revert MinAssetsRequired(minAssets, assets);

        asset.safeTransfer(msg.sender, assets);

        emit Redeem(msg.sender, shares, assets);
    }

    function _burnPosition(int24 lowerTick, int24 upperTick, uint128 shares) internal {
        manager.burnPosition(
            handler,
            abi.encode(
                IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                    pool: poolAdapter.pool(),
                    hook: handlerHook,
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
                fee: poolAdapter.fee(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: counterAssetsIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
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

    /// @inheritdoc IOrangeStrykeLPAutomatorV2_1
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

        // if needs the other token, execute flash loan, then _onFlashLoanReceived will call the multicall
        if (_execFlashLoan) {
            // prepare flash loan request
            FlashLoanUserData memory _userData = FlashLoanUserData({
                swapProxy: swapProxy,
                swapRequest: swapRequest,
                mintCalldata: _mintCalldataBatch,
                burnCalldata: _burnCalldataBatch
            });
            _flashLoanHash = keccak256(abi.encode(_userData));
            balancer.flashLoan(IBalancerFlashLoanRecipient(this), _tokens, _amounts, abi.encode(_userData));
        }
        // if not, execute multicall directly
        else {
            // burn should be called before mint to receive the assets from the burned position
            if (_burnCalldataBatch.length > 0) Multicall(address(manager)).multicall(_burnCalldataBatch);
            if (_mintCalldataBatch.length > 0) Multicall(address(manager)).multicall(_mintCalldataBatch);
        }

        // finally, check if tick count is not exceeded
        if (_activeTicks.length() > _MAX_TICKS) revert MaxTicksReached();

        emit Rebalance(msg.sender, ticksMint, ticksBurn);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external validateFlashLoan(userData) {
        if (msg.sender != address(balancer)) revert FlashLoan_Unauthorized();

        FlashLoanUserData memory _ud = abi.decode(userData, (FlashLoanUserData));

        // burn should be called before mint to receive the assets from the burned position
        if (_ud.burnCalldata.length > 0) Multicall(address(manager)).multicall(_ud.burnCalldata);
        if (_ud.mintCalldata.length > 0) Multicall(address(manager)).multicall(_ud.mintCalldata);

        // we can directly pass the request as the user data is provided by the trusted strategist
        IOrangeSwapProxy(_ud.swapProxy).safeInputSwap(_ud.swapRequest);

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
        uint256 ticks = ticksMint.length;
        mintCalldataBatch = new bytes[](ticks);

        int24 spacing = poolTickSpacing;
        address pool_ = poolAdapter.pool();

        int24 lt;
        int24 ut;
        for (uint256 i = 0; i < ticks; ) {
            lt = ticksMint[i].tick;
            ut = lt + spacing;

            mintCalldataBatch[i] = abi.encodeWithSelector(
                IDopexV2PositionManager.mintPosition.selector,
                handler,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                        pool: pool_,
                        hook: handlerHook,
                        tickLower: lt,
                        tickUpper: ut,
                        liquidity: ticksMint[i].liquidity
                    })
                )
            );

            // If the position is not active, push it to the active ticks
            if (handler.balanceOf(address(this), handler.tokenId(pool_, handlerHook, lt, ut)) == 0)
                _activeTicks.add(uint256(uint24(lt)));

            unchecked {
                i++;
            }
        }
    }

    function _createBurnCalldataBatch(
        RebalanceTick[] calldata ticksBurn
    ) internal returns (bytes[] memory burnCalldataBatch) {
        int24 spacing = poolTickSpacing;
        int24 lt;
        int24 ut;
        uint256 tid;
        uint256 shares;
        uint256 burnLength = ticksBurn.length;
        burnCalldataBatch = new bytes[](burnLength);
        for (uint256 i = 0; i < burnLength; ) {
            lt = ticksBurn[i].tick;
            ut = lt + spacing;

            address pool_ = poolAdapter.pool();

            tid = handler.tokenId(pool_, handlerHook, lt, ut);
            shares = handler.convertToShares(ticksBurn[i].liquidity, tid);
            burnCalldataBatch[i] = abi.encodeWithSelector(
                IDopexV2PositionManager.burnPosition.selector,
                handler,
                abi.encode(
                    IUniswapV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                        pool: pool_,
                        hook: handlerHook,
                        tickLower: lt,
                        tickUpper: ut,
                        shares: shares.toUint128()
                    })
                )
            );

            // if all shares will be burned, pop the active tick
            if (handler.balanceOf(address(this), tid) - shares == 0) _activeTicks.remove(uint256(uint24(lt)));

            unchecked {
                i++;
            }
        }
    }
}
