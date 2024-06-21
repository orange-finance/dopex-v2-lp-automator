// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3TWAPOracle} from "@orange-finance/oracle/src/IUniswapV3TWAPOracle.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import {IOrangeQuoter} from "./interfaces/IOrangeQuoter.sol";

error UniswapV3TWAPQuoter__PairNotConfigured();
error UniswapV3TWAPQuoter__NotAdmin();

/**
 * @title UniswapV3TWAPQuoter
 * @notice Quotes Uniswap V3 TWAP prices
 * @author Orange Finance
 */
contract UniswapV3TWAPQuoter is IOrangeQuoter {
    struct TWAPConfig {
        address pool;
        uint32 duration;
    }

    IUniswapV3TWAPOracle public immutable oracle;

    mapping(bytes32 pairId => TWAPConfig) public twapConfigs;
    mapping(address user => bool) public isAdmin;

    modifier onlyAdmin() {
        if (!isAdmin[msg.sender]) revert UniswapV3TWAPQuoter__NotAdmin();
        _;
    }

    constructor(IUniswapV3TWAPOracle oracle_) {
        oracle = oracle_;
        isAdmin[msg.sender] = true;
    }

    /**
     * @notice Returns a unique identifier for a pair. The identifier is ordered descending.
     * @dev We don't care about pool fee because Automator contract has no way to pass a fee parameter in current implementation.
     * @param tokenA The first token
     * @param tokenB The second token
     * @return The unique identifier
     */
    function pairId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA < tokenB) (tokenA, tokenB) = (tokenB, tokenA);

        return keccak256(abi.encode(tokenA, tokenB));
    }

    /**
     * @notice Returns the TWAP price for a pair
     * @param req The quote request
     * @return quote The TWAP price
     */
    function getQuote(QuoteRequest memory req) external view returns (uint256 quote) {
        TWAPConfig memory config = twapConfigs[pairId(req.baseToken, req.quoteToken)];
        if (config.pool == address(0)) revert UniswapV3TWAPQuoter__PairNotConfigured();

        return
            OracleLibrary.getQuoteAtTick(
                oracle.getTickForTWAP(config.pool, config.duration),
                uint128(req.baseAmount),
                req.baseToken,
                req.quoteToken
            );
    }

    /**
     * @notice Sets the TWAP configuration for a pair
     * @param pairId_ The unique identifier of the pair
     * @param config The TWAP configuration
     */
    function setTWAPConfig(bytes32 pairId_, TWAPConfig memory config) external onlyAdmin {
        twapConfigs[pairId_] = config;
    }

    /**
     * @notice Sets the admin status for a user
     * @param admin The address of the user
     * @param enabled The new admin status
     */
    function setAdmin(address admin, bool enabled) external onlyAdmin {
        isAdmin[admin] = enabled;
    }
}
