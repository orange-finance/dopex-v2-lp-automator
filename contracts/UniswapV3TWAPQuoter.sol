// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IUniswapV3TWAPOracle} from "@orange-finance/oracle/src/IUniswapV3TWAPOracle.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import {IOrangeQuoter} from "./interfaces/IOrangeQuoter.sol";

error UniswapV3TWAPQuoter__PairNotConfigured();
error UniswapV3TWAPQuoter__NotAdmin();

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

    function pairId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA < tokenB) (tokenA, tokenB) = (tokenB, tokenA);

        return keccak256(abi.encode(tokenA, tokenB));
    }

    function setTWAPConfig(bytes32 pairId_, TWAPConfig memory config) external onlyAdmin {
        twapConfigs[pairId_] = config;
    }

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
}
