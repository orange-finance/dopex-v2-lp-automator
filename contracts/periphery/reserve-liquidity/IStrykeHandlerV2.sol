// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IStrykeHandlerV2 {
    struct TokenIdInfo {
        uint128 totalLiquidity;
        uint128 totalSupply;
        uint128 liquidityUsed;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        uint64 lastDonation;
        uint128 donatedLiquidity;
        address token0;
        address token1;
        uint24 fee;
        uint128 reservedLiquidity;
    }

    struct BurnPositionParams {
        address pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint128 shares;
    }

    struct ReserveLiquidityData {
        uint128 liquidity;
        uint64 lastReserve;
    }

    function balanceOf(address owner, uint256 tokenId) external view returns (uint256);

    function convertToAssets(uint128 shares, uint256 tokenId) external view returns (uint128);

    function convertToShares(uint128 assets, uint256 tokenId) external view returns (uint128);

    function tokenIds(uint256 tokenId) external view returns (TokenIdInfo memory);

    function reservedLiquidityPerUser(
        uint256 tokenId,
        address user
    ) external view returns (ReserveLiquidityData memory);

    function reserveCooldown() external view returns (uint64);

    function transferFrom(address from, address to, uint256 tokenId, uint256 shares) external;

    function reserveLiquidity(bytes calldata reserveLiquidityData) external returns (uint128 sharesBurned);

    function withdrawReserveLiquidity(bytes calldata reserveLiquidityData) external;
}
