// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IDopexV2PositionManager} from "../../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
import {IUniswapV3SingleTickLiquidityHandler} from "../../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";

import {OrangeDopexV2LPAutomator, IOrangeDopexV2LPAutomator} from "../../contracts/OrangeDopexV2LPAutomator.sol";

import {Vm} from "forge-std/Test.sol";

library AutomatorHelper {
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /*/////////////////////////////////////////////////////////////////////
                                OrangeDopexV2LPAutomator utilities
    /////////////////////////////////////////////////////////////////////*/

    function deployOrangeDopexV2LPAutomator(
        Vm vm,
        string memory name,
        string memory symbol,
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
    ) external returns (OrangeDopexV2LPAutomator automator) {
        automator = new OrangeDopexV2LPAutomator({
            name: name,
            symbol: symbol,
            admin: admin,
            manager_: manager,
            handler_: uniV3Handler,
            router_: router,
            pool_: pool,
            asset_: asset,
            minDepositAssets_: minDepositAssets
        });

        vm.startPrank(admin);
        automator.setDepositCap(depositCap);
        automator.grantRole(automator.STRATEGIST_ROLE(), strategist);
        vm.stopPrank();

        vm.prank(dopexV2ManagerOwner);
        manager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(admin), true);
    }

    function rebalanceMintSingle(IOrangeDopexV2LPAutomator automator, int24 lowerTick, uint128 liquidity) internal {
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[]
            memory _ticksMint = new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](1);
        _ticksMint[0] = IOrangeDopexV2LPAutomator.RebalanceTickInfo({tick: lowerTick, liquidity: liquidity});
        automator.rebalance(
            _ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMint(
        IOrangeDopexV2LPAutomator automator,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint
    ) internal {
        automator.rebalance(
            ticksMint,
            new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0),
            IOrangeDopexV2LPAutomator.RebalanceSwapParams(0, 0, 0, 0)
        );
    }

    function rebalanceMintWithSwap(
        IOrangeDopexV2LPAutomator automator,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomator.RebalanceSwapParams memory swapParams
    ) internal {
        automator.rebalance(ticksMint, new IOrangeDopexV2LPAutomator.RebalanceTickInfo[](0), swapParams);
    }

    function rebalanceMintWithSwap(
        IOrangeDopexV2LPAutomator automator,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksMint,
        IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory ticksBurn
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
            IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory mintTicks,
            IOrangeDopexV2LPAutomator.RebalanceTickInfo[] memory burnTicks,
            IOrangeDopexV2LPAutomator.RebalanceSwapParams memory swapParams
        )
    {
        return
            abi.decode(
                _extractCalldata(data),
                (
                    IOrangeDopexV2LPAutomator.RebalanceTickInfo[],
                    IOrangeDopexV2LPAutomator.RebalanceTickInfo[],
                    IOrangeDopexV2LPAutomator.RebalanceSwapParams
                )
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
