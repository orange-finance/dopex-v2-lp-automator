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

    uint256 private constant GRACE_PERIOD_TIME = 3600;

    address public immutable l2SequencerUptimeFeed;

    error SequencerDown();
    error GracePeriodNotOver();

    constructor(address l2SequencerUptimeFeed_) {
        l2SequencerUptimeFeed = l2SequencerUptimeFeed_;
    }

    /**
     * @notice Returns the quote for a given token pair
     * @param req The quote request
     * @return quote The quote
     */
    function getQuote(QuoteRequest memory req) public view returns (uint256 quote) {
        (, int256 answer, uint256 startedAt, , ) = AggregatorV3Interface(l2SequencerUptimeFeed).latestRoundData();

        // answer == 1 means the sequencer is down (0 means it's up)
        if (answer == 1) revert SequencerDown();

        // Make sure the grace period has passed after the sequencer is back up
        if (block.timestamp - startedAt <= GRACE_PERIOD_TIME) revert GracePeriodNotOver();

        // Now we can safely calculate the quote from latest data
        uint8 baseTokenDecimals = IERC20Decimals(req.baseToken).decimals();
        uint8 quoteTokenDecimals = IERC20Decimals(req.quoteToken).decimals();

        (, int256 basePriceUsd, , , ) = AggregatorV3Interface(req.baseUsdFeed).latestRoundData();
        (, int256 quotePriceUsd, , , ) = AggregatorV3Interface(req.quoteUsdFeed).latestRoundData();

        uint256 _numerator = uint256(basePriceUsd) * req.baseAmount * 10 ** quoteTokenDecimals;
        uint256 _denominator = uint256(quotePriceUsd) * 10 ** baseTokenDecimals;

        return _numerator / _denominator;
    }
}
