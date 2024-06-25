// SPDX-License-Identifier: GPL-3.0

/* solhint-disable max-states-count */

pragma solidity 0.8.19;

import {Test, StdStorage, stdStorage} from "forge-std/Test.sol";

import {IDopexV2PositionManager} from "./../../../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandlerV2} from "./../../../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandlerV2.sol";
import {UniswapV3SingleTickLiquidityLib} from "./../../../../contracts/lib/UniswapV3SingleTickLiquidityLib.sol";
import {ChainlinkQuoter} from "./../../../../contracts/ChainlinkQuoter.sol";
import {StrykeVaultInspector} from "./../../../../contracts/periphery/StrykeVaultInspector.sol";
import {OrangeKyberswapProxy} from "./../../../../contracts/swap-proxy/OrangeKyberswapProxy.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IBalancerVault} from "../../../../contracts/vendor/balancer/IBalancerVault.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {UniswapV3Helper} from "../../../helper/UniswapV3Helper.t.sol";
import {DopexV2Helper} from "../../../helper/DopexV2Helper.t.sol";
import {MockSwapProxy} from "../mock/MockSwapProxy.sol";

contract BaseFixture is Test {
    using stdStorage for StdStorage;
    using FullMath for uint256;
    using UniswapV3Helper for IUniswapV3Pool;
    using DopexV2Helper for IUniswapV3Pool;
    using UniswapV3SingleTickLiquidityLib for IUniswapV3SingleTickLiquidityHandlerV2;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public dave = makeAddr("dave");

    // Stryke
    IUniswapV3SingleTickLiquidityHandlerV2 public handlerV2 =
        IUniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
    IDopexV2PositionManager public manager = IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    address public dopexV2OptionMarket = 0x764fA09d0B3de61EeD242099BD9352C1C61D3d27;
    address public managerOwner = 0x880C3cdCA73254D466f9c716248339dE88e4a97D;

    // Uniswap V3
    ISwapRouter public router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    // Balancer
    IBalancerVault public balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    // Kyberswap
    address public kyberswapRouter = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

    // base contracts
    ChainlinkQuoter public chainlinkQuoter;
    StrykeVaultInspector public inspector;
    OrangeKyberswapProxy public kyberswapProxy;

    // mock contracts
    MockSwapProxy public mockSwapProxy;

    // solhint-disable-next-line no-empty-blocks
    function setUp() public virtual {
        chainlinkQuoter = new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D));

        inspector = new StrykeVaultInspector();

        kyberswapProxy = new OrangeKyberswapProxy();
        kyberswapProxy.setTrustedProvider(kyberswapRouter, true);

        mockSwapProxy = new MockSwapProxy();

        vm.prank(managerOwner);
        manager.updateWhitelistHandlerWithApp(address(handlerV2), address(this), true);
    }
}
