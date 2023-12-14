// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";

import {Automator, IAutomator} from "../../contracts/Automator.sol";

import {Vm} from "forge-std/Test.sol";

library AutomatorHelper {
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function deployAutomator(
        Vm vm,
        address dopexV2ManagerOwner,
        address admin,
        address strategist,
        IDopexV2PositionManager manager,
        IUniswapV3SingleTickLiquidityHandler uniV3Handler,
        ISwapRouter router,
        IUniswapV3Pool pool,
        IERC20 asset,
        uint256 minDepositAssets,
        uint256 depositCap
    ) external returns (Automator automator) {
        automator = new Automator({
            admin: admin,
            manager_: manager,
            handler_: uniV3Handler,
            router_: router,
            pool_: pool,
            asset_: asset,
            minDepositAssets_: minDepositAssets
        });

        automator.setDepositCap(depositCap);
        automator.grantRole(automator.STRATEGIST_ROLE(), strategist);

        vm.prank(dopexV2ManagerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(automator), true);
    }

    function rebalanceMintSingle(IAutomator automator, int24 lowerTick, uint128 liquidity) internal {
        IAutomator.RebalanceTickInfo[] memory _ticksMint = new IAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IAutomator.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IAutomator.RebalanceTickInfo[](0),
            IAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMint(IAutomator automator, IAutomator.RebalanceTickInfo[] memory ticksMint) internal {
        automator.rebalance(
            ticksMint,
            new IAutomator.RebalanceTickInfo[](0),
            IAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }
}
