// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UniswapV3Helper, IUniswapV3Pool} from "./helper/UniswapV3Helper.t.sol";
import {ChainlinkQuoter} from "../contracts/ChainlinkQuoter.sol";

contract TestChainlinkQuoter is Test {
    ChainlinkQuoter quoter;

    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    function setUp() public {
        vm.createSelectFork("arb", 168679427);

        quoter = new ChainlinkQuoter(address(0xFdB631F5EE196F0ed6FAa767959853A9F217697D));
        quoter.setStalenessThreshold(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 86400);
        quoter.setStalenessThreshold(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 86400);
        quoter.setStalenessThreshold(0xd0C7101eACbB49F3deCcCc166d238410D6D46d57, 86400);
        quoter.setStalenessThreshold(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6, 86400);
    }

    function test_getQuote_ethToUsdc() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            WETH,
            USDC,
            10_000 ether
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: USDC,
                baseAmount: 10_000 ether,
                baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_usdcToEth() public {
        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            USDC,
            WETH,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDC,
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
            USDC,
            10_000e8
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WBTC,
                quoteToken: USDC,
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
            USDC,
            WBTC,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDC,
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
            USDC,
            1_000_000e18
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: ARB,
                quoteToken: USDC,
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
            USDC,
            ARB,
            100_000e6
        );

        uint256 clQuote = quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: USDC,
                quoteToken: ARB,
                baseAmount: 100_000e6,
                baseUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                quoteUsdFeed: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6
            })
        );

        assertApproxEqRel(uniQuote, clQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_noBaseFallbackOracleSet() public {
        // assume the primary WETH oracle is down
        vm.mockCallRevert(
            0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode("UNAVAILABLE")
        );

        vm.expectRevert(ChainlinkQuoter.FeedNotAvailable.selector);
        quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: USDC,
                baseAmount: 10_000 ether,
                baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );
    }

    function test_getQuote_revert_noQuoteFallbackOracleSet() public {
        // assume the primary USDC.e oracle is down
        vm.mockCallRevert(
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode("UNAVAILABLE")
        );

        vm.expectRevert(ChainlinkQuoter.FeedNotAvailable.selector);
        quoter.getQuote(
            ChainlinkQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: USDC,
                baseAmount: 10_000 ether,
                baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );
    }

    function test_getQuote_fallbackToSecondaryBaseOracle() public {
        // assume the primary ETH oracle is down
        vm.mockCallRevert(
            0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode("UNAVAILABLE")
        );

        address secondaryBaseOracle = makeAddr("secondEthOracle");

        // return same price as primary oracle
        vm.mockCall(
            secondaryBaseOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(229899026182), uint256(0), block.timestamp, uint80(0))
        );

        quoter.setSecondaryOracleOf(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, secondaryBaseOracle);

        assertEq(
            quoter.getQuote(
                ChainlinkQuoter.QuoteRequest({
                    baseToken: WETH,
                    quoteToken: USDC,
                    baseAmount: 10_000 ether,
                    baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                    quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
                })
            ),
            22987155653099
        );
    }

    function test_getQuote_fallbackToSecondaryQuoteOracle() public {
        // assume the primary USDC.e oracle is down
        vm.mockCallRevert(
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode("UNAVAILABLE")
        );

        address secondaryQuoteOracle = makeAddr("secondUsdceOracle");

        // return same price as primary oracle
        vm.mockCall(
            secondaryQuoteOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(100011950), uint256(0), block.timestamp, uint80(0))
        );

        quoter.setSecondaryOracleOf(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, secondaryQuoteOracle);

        assertEq(
            quoter.getQuote(
                ChainlinkQuoter.QuoteRequest({
                    baseToken: WETH,
                    quoteToken: USDC,
                    baseAmount: 10_000 ether,
                    baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                    quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
                })
            ),
            22987155653099
        );
    }
}
