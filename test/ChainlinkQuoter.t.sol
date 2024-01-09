// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {UniswapV3Helper, IUniswapV3Pool} from "./helper/UniswapV3Helper.t.sol";

import {ChainlinkQuoter} from "../contracts/ChainlinkQuoter.sol";

contract TestChainlinkQuoter is Test {
    ChainlinkQuoter quoter;

    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDCE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    function setUp() public {
        vm.createSelectFork("arb", 168679427);
        quoter = new ChainlinkQuoter();
    }

    function test_getQuote_ethToUsdc() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443),
            WETH,
            USDCE,
            10_000 ether
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: USDCE,
                baseAmount: 10_000 ether,
                baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_usdcToEth() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443),
            USDCE,
            WETH,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDCE,
                quoteToken: WETH,
                baseAmount: 100_000e6,
                baseUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                quoteUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_wbtcToUsdc() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xac70bD92F89e6739B3a08Db9B6081a923912f73D),
            WBTC,
            USDCE,
            10_000e8
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WBTC,
                quoteToken: USDCE,
                baseAmount: 10_000e8,
                baseUsdFeed: 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.0015e18); // 0.15%
    }

    function test_getQuote_usdcToWbtc() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xac70bD92F89e6739B3a08Db9B6081a923912f73D),
            USDCE,
            WBTC,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDCE,
                quoteToken: WBTC,
                baseAmount: 100_000e6,
                baseUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                quoteUsdFeed: 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.0015e18); // 0.15%
    }

    function test_getQuote_arbToUsdc() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xcDa53B1F66614552F834cEeF361A8D12a0B8DaD8),
            ARB,
            USDCE,
            1_000_000e18
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: ARB,
                quoteToken: USDCE,
                baseAmount: 1_000_000e18,
                baseUsdFeed: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_UsdcToArb() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xcDa53B1F66614552F834cEeF361A8D12a0B8DaD8),
            USDCE,
            ARB,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDCE,
                quoteToken: ARB,
                baseAmount: 100_000e6,
                baseUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                quoteUsdFeed: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }
}
