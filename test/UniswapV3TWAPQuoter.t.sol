// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase */

import {Test} from "forge-std/Test.sol";
import {IUniswapV3TWAPOracle} from "@orange-finance/oracle/src/IUniswapV3TWAPOracle.sol";

import {UniswapV3Helper, IUniswapV3Pool} from "./helper/UniswapV3Helper.t.sol";
import {UniswapV3TWAPQuoter} from "../contracts/UniswapV3TWAPQuoter.sol";
import {IOrangeQuoter} from "../contracts/interfaces/IOrangeQuoter.sol";

contract TestUniswapV3TWAPQuoter is Test {
    IUniswapV3TWAPOracle public twapOracle = IUniswapV3TWAPOracle(0x4487d08B77530AAdEb11459f1BC19b479f90d8F9);

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant BOOP = 0x13A7DeDb7169a17bE92B0E3C7C2315B46f4772B3;

    UniswapV3TWAPQuoter public quoter;

    function setUp() public {
        vm.createSelectFork("arb", 217911867);

        quoter = new UniswapV3TWAPQuoter(twapOracle);
    }

    function test_getQuote_ethToUsdc() public {
        quoter.setTWAPConfig(
            quoter.pairId(WETH, USDC),
            UniswapV3TWAPQuoter.TWAPConfig({pool: 0xC6962004f452bE9203591991D15f6b388e09E8D0, duration: 5 minutes})
        );

        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            WETH,
            USDC,
            10_000 ether
        );

        uint256 twapQuote = quoter.getQuote(
            IOrangeQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: USDC,
                baseAmount: 10_000 ether,
                baseUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
                quoteUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
            })
        );

        assertApproxEqRel(uniQuote, twapQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_usdcToEth() public {
        quoter.setTWAPConfig(
            quoter.pairId(WETH, USDC),
            UniswapV3TWAPQuoter.TWAPConfig({pool: 0xC6962004f452bE9203591991D15f6b388e09E8D0, duration: 5 minutes})
        );

        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            USDC,
            WETH,
            100_000e6
        );

        uint256 twapQuote = quoter.getQuote(
            IOrangeQuoter.QuoteRequest({
                baseToken: USDC,
                quoteToken: WETH,
                baseAmount: 100_000e6,
                baseUsdFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                quoteUsdFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
            })
        );

        assertApproxEqRel(uniQuote, twapQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_boopToWeth() public {
        quoter.setTWAPConfig(
            quoter.pairId(WETH, BOOP),
            UniswapV3TWAPQuoter.TWAPConfig({pool: 0xe24F62341D84D11078188d83cA3be118193D6389, duration: 10 minutes})
        );

        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xe24F62341D84D11078188d83cA3be118193D6389),
            BOOP,
            WETH,
            1_000_000e18
        );

        uint256 twapQuote = quoter.getQuote(
            IOrangeQuoter.QuoteRequest({
                baseToken: BOOP,
                quoteToken: WETH,
                baseAmount: 1_000_000e18,
                baseUsdFeed: address(0),
                quoteUsdFeed: address(0)
            })
        );

        assertApproxEqRel(uniQuote, twapQuote, 0.001e18); // 0.1%
    }

    function test_getQuote_wethToBoop() public {
        quoter.setTWAPConfig(
            quoter.pairId(WETH, BOOP),
            UniswapV3TWAPQuoter.TWAPConfig({pool: 0xe24F62341D84D11078188d83cA3be118193D6389, duration: 5 minutes})
        );

        uint256 uniQuote = UniswapV3Helper.getQuote(
            IUniswapV3Pool(0xe24F62341D84D11078188d83cA3be118193D6389),
            WETH,
            BOOP,
            10_000e18
        );

        uint256 twapQuote = quoter.getQuote(
            IOrangeQuoter.QuoteRequest({
                baseToken: WETH,
                quoteToken: BOOP,
                baseAmount: 10_000e18,
                baseUsdFeed: address(0),
                quoteUsdFeed: address(0)
            })
        );

        assertApproxEqRel(uniQuote, twapQuote, 0.001e18); // 0.1%
    }
}
