// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {OrangeStrykeLPAutomatorV1_1} from "contracts/v1_1/OrangeStrykeLPAutomatorV1_1.sol";
import {OrangeStrykeLPAutomatorV2} from "contracts/v2/OrangeStrykeLPAutomatorV2.sol";
import {OrangeStrykeLPAutomatorV2_1} from "contracts/v2_1/OrangeStrykeLPAutomatorV2_1.sol";
import {OrangeStrykeLPAutomatorV2_2} from "contracts/v2_2/OrangeStrykeLPAutomatorV2_2.sol";
import {IOrangeQuoter} from "contracts/interfaces/IOrangeQuoter.sol";
import {IUniswapV3PoolAdapter} from "contracts/pool-adapter/IUniswapV3PoolAdapter.sol";
import {IDopexV2PositionManager} from "contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IBalancerVault} from "contracts/vendor/balancer/IBalancerVault.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeToV2_2 is Test {
    address public automator;
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public handlerV2 = 0x29BbF7EbB9C5146c98851e76A5529985E4052116;
    address public strykeHookMock = makeAddr("strykeHookMock");
    address public oldManager = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;
    address public newManagerMock = makeAddr("newManagerMock");
    address public uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public wethUsdcPool = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
    address public uniswapQuoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public kyberswapRouter = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public chainlinkQuoterMock = makeAddr("chainlinkQuoterMock");
    address public assetUsdFeed = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address public counterAssetUsdFeed = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
    address public inspectorMock = makeAddr("inspectorMock");
    address public kyberswapProxyMock = makeAddr("kyberswapProxyMock");
    address public poolAdapterMock = makeAddr("poolAdapterMock");

    function setUp() public {
        vm.createSelectFork("arb", 310277805);
        vm.mockCall(
            address(poolAdapterMock),
            abi.encodeWithSelector(IUniswapV3PoolAdapter.pool.selector),
            abi.encode(IUniswapV3Pool(wethUsdcPool))
        );
    }

    function deployV2_1() public {
        // deploy and initialize v1_1
        OrangeStrykeLPAutomatorV1_1.InitArgs memory initArgs = OrangeStrykeLPAutomatorV1_1.InitArgs({
            name: "osykWETH-USDC",
            symbol: "osykWETH-USDC",
            admin: address(this),
            manager: IDopexV2PositionManager(oldManager),
            handler: IUniswapV3SingleTickLiquidityHandlerV2(handlerV2),
            handlerHook: strykeHookMock,
            router: ISwapRouter(uniswapV3Router),
            pool: IUniswapV3Pool(wethUsdcPool),
            asset: IERC20(weth),
            quoter: IOrangeQuoter(chainlinkQuoterMock),
            assetUsdFeed: assetUsdFeed,
            counterAssetUsdFeed: counterAssetUsdFeed,
            minDepositAssets: 0.001e18 + 1
        });
        automator = address(
            new ERC1967Proxy(
                address(new OrangeStrykeLPAutomatorV1_1()),
                abi.encodeCall(OrangeStrykeLPAutomatorV1_1.initialize, (initArgs))
            )
        );

        // upgrade to v2
        OrangeStrykeLPAutomatorV1_1(automator).upgradeToAndCall(
            address(new OrangeStrykeLPAutomatorV2()),
            abi.encodeCall(OrangeStrykeLPAutomatorV2.initializeV2, (IBalancerVault(balancerVault)))
        );

        // upgrade to v2_1
        OrangeStrykeLPAutomatorV2(automator).upgradeToAndCall(
            address(new OrangeStrykeLPAutomatorV2_1()),
            abi.encodeCall(OrangeStrykeLPAutomatorV2_1.initializeV2_1, (IUniswapV3PoolAdapter(poolAdapterMock)))
        );

        OrangeStrykeLPAutomatorV2_1(automator).setDepositCap(1e18);
        OrangeStrykeLPAutomatorV2_1(automator).setStrategist(address(this), true);
        OrangeStrykeLPAutomatorV2_1(automator).setDepositFeePips(address(this), 100);
    }

    function test_upgradeToV2_2() public {
        deployV2_1();

        OrangeStrykeLPAutomatorV2_1 automatorV2_1 = OrangeStrykeLPAutomatorV2_1(automator);
        assertEq(address(automatorV2_1.manager()), oldManager, "!old manager");

        automatorV2_1.upgradeTo(address(new OrangeStrykeLPAutomatorV2_2()));

        OrangeStrykeLPAutomatorV2_2 automatorV2_2 = OrangeStrykeLPAutomatorV2_2(automator);
        automatorV2_2.setPositionManager(newManagerMock);

        // check if upgrade is successful
        assertEq(address(automatorV2_2.manager()), newManagerMock, "!new manager");

        // check if it does not affect existing states
        assertEq(automatorV2_2.name(), "osykWETH-USDC", "!name");
        assertEq(automatorV2_2.symbol(), "osykWETH-USDC", "!symbol");
        assertEq(automatorV2_2.isOwner(address(this)), true, "!isOwner");
        assertEq(automatorV2_2.isStrategist(address(this)), true, "!isStrategist");
        assertEq(address(automatorV2_2.asset()), weth, "!asset");
        assertEq(address(automatorV2_2.counterAsset()), usdc, "!counterAsset");
        assertEq(automatorV2_2.minDepositAssets(), 0.001e18 + 1, "!minDepositAssets");
        assertEq(automatorV2_2.depositCap(), 1e18, "!depositCap");
        assertEq(automatorV2_2.depositFeePips(), 100, "!depositFeePips");
        assertEq(automatorV2_2.depositFeeRecipient(), address(this), "!depositFeeRecipient");
        assertEq(address(automatorV2_2.handler()), handlerV2, "!handler");
        assertEq(automatorV2_2.handlerHook(), strykeHookMock, "!handlerHook");
        assertEq(address(automatorV2_2.quoter()), chainlinkQuoterMock, "!quoter");
        assertEq(automatorV2_2.assetUsdFeed(), assetUsdFeed, "!assetUsdFeed");
        assertEq(automatorV2_2.counterAssetUsdFeed(), counterAssetUsdFeed, "!counterAssetUsdFeed");
        assertEq(address(automatorV2_2.pool()), wethUsdcPool, "!pool");
        assertEq(address(automatorV2_2.router()), uniswapV3Router, "!router");
        assertEq(automatorV2_2.poolTickSpacing(), 10, "!poolTickSpacing");
        assertEq(address(automatorV2_2.balancer()), balancerVault, "!balancer");
        assertEq(automatorV2_2.swapInputDelta(), 10, "!swapInputDelta");
        assertEq(address(automatorV2_2.poolAdapter()), poolAdapterMock, "!poolAdapter");
    }
}
