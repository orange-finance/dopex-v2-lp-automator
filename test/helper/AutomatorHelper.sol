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

    /*/////////////////////////////////////////////////////////////////////
                                Automator utilities
    /////////////////////////////////////////////////////////////////////*/

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
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(admin), true);
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

    function rebalanceMintWithSwap(
        IAutomator automator,
        IAutomator.RebalanceTickInfo[] memory ticksMint,
        IAutomator.RebalanceSwapParams memory swapParams
    ) internal {
        automator.rebalance(ticksMint, new IAutomator.RebalanceTickInfo[](0), swapParams);
    }

    function rebalanceMintWithSwap(
        IAutomator automator,
        IAutomator.RebalanceTickInfo[] memory ticksMint,
        IAutomator.RebalanceTickInfo[] memory ticksBurn
    ) internal {
        automator.rebalance(
            ticksMint,
            ticksBurn,
            automator.calculateRebalanceSwapParamsInRebalance(ticksMint, ticksBurn)
        );
    }

    /*/////////////////////////////////////////////////////////////////////
                                Strategy utilities
    /////////////////////////////////////////////////////////////////////*/

    function decodeCheckLiquidizePooledAssets(
        bytes memory data
    )
        internal
        pure
        returns (
            IAutomator.RebalanceTickInfo[] memory mintTicks,
            IAutomator.RebalanceTickInfo[] memory burnTicks,
            IAutomator.RebalanceSwapParams memory swapParams
        )
    {
        return
            abi.decode(
                _extractCalldata(data),
                (IAutomator.RebalanceTickInfo[], IAutomator.RebalanceTickInfo[], IAutomator.RebalanceSwapParams)
            );
    }

    // https://ethereum.stackexchange.com/questions/131283/how-do-i-decode-call-data-in-solidity
    function _extractCalldata(bytes memory calldataWithSelector) internal pure returns (bytes memory) {
        bytes memory calldataWithoutSelector;

        require(calldataWithSelector.length >= 4);

        assembly {
            let totalLength := mload(calldataWithSelector)
            let targetLength := sub(totalLength, 4)
            calldataWithoutSelector := mload(0x40)

            // Set the length of callDataWithoutSelector (initial length - 4)
            mstore(calldataWithoutSelector, targetLength)

            // Mark the memory space taken for callDataWithoutSelector as allocated
            mstore(0x40, add(calldataWithoutSelector, add(0x20, targetLength)))

            // Process first 32 bytes (we only take the last 28 bytes)
            mstore(add(calldataWithoutSelector, 0x20), shl(0x20, mload(add(calldataWithSelector, 0x20))))

            // Process all other data by chunks of 32 bytes
            for {
                let i := 0x1C
            } lt(i, targetLength) {
                i := add(i, 0x20)
            } {
                mstore(
                    add(add(calldataWithoutSelector, 0x20), i),
                    mload(add(add(calldataWithSelector, 0x20), add(i, 0x04)))
                )
            }
        }

        return calldataWithoutSelector;
    }
}
