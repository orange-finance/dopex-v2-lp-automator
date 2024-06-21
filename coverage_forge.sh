#!/usr/bin/env bash

# forked from: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/e91c3100c29d2913d175df4b3d1790d6a057d36e/solidity/coverage.sh

set -e # exit on error

# generates lcov.info
forge coverage --report lcov --no-match-test "Skip"

# Open more granular breakdown in browser
if [ "$CI" != "true" ]; then
    genhtml \
        --rc branch_coverage=1 \
        --output-directory coverage \
        --ignore-errors category \
        lcov.info
    open coverage/index.html
fi
