// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Decimals} from "./interfaces/IERC20Extended.sol";

/**
 * @title ChainlinkQuoter
 * @notice Provides quotes for token pairs using Chainlink price feeds
 */
contract ChainlinkQuoter {
    /**
     * @notice Quote request
     * @param baseToken The base token to get a quote for
     * @param quoteToken The quote token
     * @param baseAmount The base amount with decimals
     * @param baseUsdFeed The base token USD price feed by Chainlink
     * @param quoteUsdFeed The quote token USD price feed by Chainlink
     */
    struct QuoteRequest {
        address baseToken;
        address quoteToken;
        uint256 baseAmount;
        address baseUsdFeed;
        address quoteUsdFeed;
    }

    /**
     * @notice Returns the quote for a given token pair
     * @param req The quote request
     * @return quote The quote
     */
    function getQuote(QuoteRequest memory req) public view returns (uint256 quote) {
        uint8 baseTokenDecimals = IERC20Decimals(req.baseToken).decimals();
        uint8 quoteTokenDecimals = IERC20Decimals(req.quoteToken).decimals();

        (, int256 basePriceUsd, , , ) = AggregatorV3Interface(req.baseUsdFeed).latestRoundData();
        (, int256 quotePriceUsd, , , ) = AggregatorV3Interface(req.quoteUsdFeed).latestRoundData();

        uint256 _numerator = uint256(basePriceUsd) * req.baseAmount * 10 ** quoteTokenDecimals;
        uint256 _denominator = uint256(quotePriceUsd) * 10 ** baseTokenDecimals;

        return _numerator / _denominator;
    }
}
