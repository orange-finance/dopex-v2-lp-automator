#!/usr/bin/env bash

# forked from: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/e91c3100c29d2913d175df4b3d1790d6a057d36e/solidity/coverage.sh

# FIXME: Some of lines are not included in the coverage report when merging the two lcov files.

set -e # exit on error

# generates lcov.info
forge coverage --report lcov --no-match-test "Skip"

# generates coverage/lcov.info
npx hardhat coverage

# Foundry uses relative paths but Hardhat uses absolute paths.
# Convert absolute paths to relative paths for consistency.
# sed -i -e 's/\/.*solidity.//g' coverage/lcov.info
sed -i -e 's/\/.*dopex-v2-lp-automator\///g' coverage/lcov.info

# Merge lcov files
lcov \
    --rc branch_coverage=1 \
    --add-tracefile lcov.info \
    --add-tracefile coverage/lcov.info \
    --output-file merged-lcov.info

# Filter out test files
lcov \
    --rc branch_coverage=1 \
    --remove merged-lcov.info \
    --output-file filtered-lcov.info \
    "*test*"

# Generate summary
lcov \
    --rc branch_coverage=1 \
    --list filtered-lcov.info

# Open more granular breakdown in browser
if [ "$CI" != "true" ]; then
    genhtml \
        --rc branch_coverage=1 \
        --output-directory coverage \
        --ignore-errors category \
        filtered-lcov.info
    open coverage/index.html
fi
