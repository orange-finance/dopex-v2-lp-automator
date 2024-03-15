// SPDX-License-Identifier: GPL-3.0
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IOrangeStrykeLPAutomatorV2} from "../../../contracts/v2/IOrangeStrykeLPAutomatorV2.sol";
import {IOrangeSwapProxy} from "./../../../contracts/v2/IOrangeSwapProxy.sol";
import {IBalancerVault} from "../../../contracts/vendor/balancer/IBalancerVault.sol";
import {IBalancerFlashLoanRecipient} from "../../../contracts/vendor/balancer/IBalancerFlashLoanRecipient.sol";
import {UniswapV3Helper} from "../../helper/UniswapV3Helper.t.sol";
import {WETH_USDC_Fixture} from "./fixture/WETH_USDC_Fixture.t.sol";

contract TestOrangeStrykeLPAutomatorV2Rebalance is WETH_USDC_Fixture {
    using UniswapV3Helper for IUniswapV3Pool;

    bytes public constant SWAP_CALLDATA_STATIC =
        hex"e21fd0e9000000000000000000000000000000000000000000000000000000000000002000000000000000000000000011ddd59c33c73c44733b4123a86ea5ce57f6e854000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000004e0000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000004160a010000002902000000c6962004f452be9203591991d15f6b388e09e8d00000000000000000ad78ebc5ac620000010a01000000290200000030afbcf9458c3131a6d051c621e307e6278e4110000000000000000022b1c8c1227a0000010a030000002902000000c31e54c7a869b9fcbecc14363cf510d1c41fa443000000000000000022b1c8c1227a0000010a0000002e0000009dd329f5411466d9e0c488ff72519ca9fef0cb4002019dd329f5411466d9e0c488ff72519ca9fef0cb4001080000002e02000000fc43aaf89a71acaa644842ee4219e8eb77657427af88d065e77c8cc2239327c5edb3a432268e583100011b020000002902000000641c00a822e8b671738d32a431a4fb6074e5c79d00000000000000008ac7230489e80000010a0000004d02000000a17afcab059f3c6751f5b64347b5a503c3291868af88d065e77c8cc2239327c5edb3a432268e5831010000000000000000000000000000000000000000000000000000000000000000150200000029020000002760cc828b2e4d04f8ec261a5335426bb22d9291000000000000000022b1c8c1227a0000010a0000001a020000000e4831319a50228b9e450861297ab92dee15b44f01010a010000003d0200000069f1216cb2905bf0852f74624d5fa7b5fc4da710af88d065e77c8cc2239327c5edb3a432268e58310000000000000000008ac7230489e800001b020000002902000000c31e54c7a869b9fcbecc14363cf510d1c41fa443000000000000000022b1c8c1227a0000010a0000001a02000000562d29b54d2c57f8620c920415c4dceadd6de2d201010a030000002902000000641c00a822e8b671738d32a431a4fb6074e5c79d000000000000000022b1c8c1227a0000010a0000002f02000000e4b2dfc82977dd2dce7e8d37895a6a8f50cbb4fb01a5f36e822540efd11fcd77ec46626b916b217c3e01000c0000001a02000000562d29b54d2c57f8620c920415c4dceadd6de2d201010a010000005c02000000b1026b8e7276e7ac75410f1fcbbe21796e8f7526af88d065e77c8cc2239327c5edb3a432268e5831000000000000000022b1c8c1227a0000000000000000000000000000000000000000000000000000000000000000000015020000002902000000e754841b77c874135caca3386676e886459c2d61000000000000000022b1c8c1227a0000010a0000001a02000000562d29b54d2c57f8620c920415c4dceadd6de2d201010a82af49447d8a07e3bd95bd0d56f35241523fbab1af88d065e77c8cc2239327c5edb3a432268e58317bb886e6fce69554e427e4dcc5cd8eaf5a3c9dd000000000000000000000000065f45ea60000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d1e900000000000000000000002b0784d4f60000000000000000000000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002000000000000000000000000007bb886e6fce69554e427e4dcc5cd8eaf5a3c9dd0000000000000000000000000000000000000000000000002b5e3af16b18800000000000000000000000000000000000000000000000000000000002afc80dbea00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000011ddd59c33c73c44733b4123a86ea5ce57f6e8540000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000002b5e3af16b188000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001eb7b22536f75726365223a22222c22416d6f756e74496e555344223a223138343937372e3630383932373931323035222c22416d6f756e744f7574555344223a223138343830392e3733393531222c22526566657272616c223a22222c22466c616773223a322c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a225839415a344a6c3977734a4451795530576c4b32434a50504d584a5a4a584d59656666455a504e54464f347a7834366957734d33463079376f56504d376c32396359744b697a7074424c4f714f61754c6f4e45502f504330594252522b532f787a424d426e6c4d52714a354f532f5753587a42374a4742585a69727a337a5643366458434170505267674d4834466d6a714770476b6f4449576f636a776a344d344a37496e6431636561355a3047756269495375683231557552664a66796351667037304257476a55424e34495175536a486359717a5277524a6c4766715a5a6534556b6c584b4a7a4448676a33754253453270503848714b63325262327155716e462b674946745759412b596c3258496f3352322f77414e7a4a6b7a3638597367535531374447347961444f52666a39677950484a445a6b453975583534513233766b4d307955655848377133643172522b5244673d3d227d7d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    uint256 public arbFork;

    function setUp() public override {
        arbFork = vm.createSelectFork("arb");
        super.setUp();
    }

    // for getting quick feedback
    function test_rebalance_flashLoanAndSwap_static() public {
        // pin the fork
        vm.rollFork(arbFork, 190654096);
        super.setUp();

        automator.deposit(100 ether, alice);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator.automator())));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator.automator())));

        uint256 estUsdc = automator.automator().pool().getQuote(address(WETH), address(USDC), 50 ether);

        IOrangeSwapProxy.SwapInputRequest memory req = IOrangeSwapProxy.SwapInputRequest({
            provider: kyberswapRouter,
            swapCalldata: SWAP_CALLDATA_STATIC,
            expectTokenIn: WETH,
            expectTokenOut: USDC,
            expectAmountIn: 50 ether,
            inputDelta: 5 // 0.05% slippage
        });

        _expectFlashLoanCall(address(USDC), estUsdc, address(kyberswapProxy), req, new bytes[](0), new bytes[](0));

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = estUsdc;

        automator.rebalance("[]", "[]", address(kyberswapProxy), req, abi.encode(tokens, amounts, true));

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator.automator()))); // prettier-ignore
    }

    function test_rebalance_flashLoanAndSwap_dynamic_Skip() public {
        automator.deposit(100 ether, alice);

        (address router, bytes memory swapCalldata) = _buildKyberswapData(address(automator.automator()), 50);

        emit log_named_uint("vault weth balance before: ", WETH.balanceOf(address(automator.automator())));
        emit log_named_uint("vault usdc balance before: ", USDC.balanceOf(address(automator.automator())));

        uint256 estUsdc = automator.automator().pool().getQuote(address(WETH), address(USDC), 50 ether);

        IOrangeSwapProxy.SwapInputRequest memory req = IOrangeSwapProxy.SwapInputRequest({
            provider: router,
            swapCalldata: swapCalldata,
            expectTokenIn: WETH,
            expectTokenOut: USDC,
            expectAmountIn: 50 ether,
            inputDelta: 5 // 0.05% slippage
        });

        _expectFlashLoanCall(address(USDC), estUsdc, address(kyberswapProxy), req, new bytes[](0), new bytes[](0));

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = estUsdc;

        automator.rebalance("[]", "[]", address(kyberswapProxy), req, abi.encode(tokens, amounts, true));

        emit log_named_uint("vault weth balance after: ", WETH.balanceOf(address(automator.automator()))); // prettier-ignore
        emit log_named_uint("vault usdc balance after: ", USDC.balanceOf(address(automator.automator()))); // prettier-ignore
    }

    function _buildKyberswapData(
        address sender,
        uint256 amount
    ) internal returns (address router, bytes memory swapCalldata) {
        string[] memory buildSwapData = new string[](12);
        buildSwapData[0] = "node";
        buildSwapData[1] = "test/OrangeDopexV2LPAutomator/v2/kyberswap.mjs";
        buildSwapData[2] = "-i";
        buildSwapData[3] = "weth";
        buildSwapData[4] = "-o";
        buildSwapData[5] = "usdc";
        buildSwapData[6] = "-u";
        buildSwapData[7] = "18";
        buildSwapData[8] = "-a";
        buildSwapData[9] = Strings.toString(amount);
        buildSwapData[10] = "-s";
        buildSwapData[11] = Strings.toHexString(uint256(uint160(sender)));

        bytes memory swapData = vm.ffi(buildSwapData);
        (router, swapCalldata) = abi.decode(swapData, (address, bytes));
    }

    function _expectFlashLoanCall(
        address borrowToken,
        uint256 amount,
        address swapProxy,
        IOrangeSwapProxy.SwapInputRequest memory swapRequest,
        bytes[] memory mintCalldataBatch,
        bytes[] memory burnCalldataBatch
    ) internal {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = IERC20(borrowToken);
        amounts[0] = amount;
        IOrangeStrykeLPAutomatorV2.FlashLoanUserData memory ud = IOrangeStrykeLPAutomatorV2.FlashLoanUserData({
            swapProxy: swapProxy,
            swapRequest: swapRequest,
            mintCalldata: mintCalldataBatch,
            burnCalldata: burnCalldataBatch
        });
        bytes memory flashLoanCall = abi.encodeCall(
            IBalancerVault.flashLoan,
            (IBalancerFlashLoanRecipient(address(automator.automator())), tokens, amounts, abi.encode(ud))
        );

        emit log_named_bytes("expect call bytes", flashLoanCall);
        vm.expectCall(address(balancer), flashLoanCall);
    }
}
