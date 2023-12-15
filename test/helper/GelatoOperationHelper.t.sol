// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IAutomate, IProxyModule, IOpsProxyFactory, Module, ModuleData, Gelato1BalanceParam} from "../vendor/gelato/Types.sol";

library GelatoOperationHelper {
    // these address are same across the networks without zkSync Era
    IAutomate constant AUTOMATE = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    address constant GELATO_SINGLE_EXEC_MODULE = 0xF778e8dB5aAFa699F47ea4579b7bd311650E71cF;
    IProxyModule constant GELATO_PROXY_MODULE = IProxyModule(0x4C416F12B4c24559A38d5A93940d4b98e0aEF4D7);

    // this address is different across the networks
    address constant GELATO_EXECUTOR_ARB = 0x4775aF8FEf4809fE10bf05867d2b038a4b5B2146;

    function createGelatoSingleExecTask_arb(
        address execContract,
        bytes memory execCalldata
    ) internal returns (bytes32 taskId) {
        return
            AUTOMATE.createTask({
                execAddress: execContract,
                execDataOrSelector: execCalldata,
                moduleData: moduleData_singleExecTask(),
                // equal to chain native token
                feeToken: address(0)
            });
    }

    function moduleData_singleExecTask() internal pure returns (ModuleData memory) {
        Module[] memory _modules = new Module[](2);
        _modules[0] = Module.PROXY;
        _modules[1] = Module.SINGLE_EXEC;

        bytes[] memory _args = new bytes[](2);
        _args[0] = bytes("");
        _args[1] = bytes("");

        return ModuleData({modules: _modules, args: _args});
    }

    function oneBalanceParam(
        address sponsor,
        uint256 chainId,
        bytes32 correlationId
    ) internal pure returns (Gelato1BalanceParam memory) {
        return
            // TODO: research more about these params
            Gelato1BalanceParam({
                sponsor: sponsor,
                feeToken: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                oneBalanceChainId: chainId,
                nativeToFeeTokenXRateNumerator: 1,
                nativeToFeeTokenXRateDenominator: 1,
                correlationId: correlationId
            });
    }

    function dedicatedMsgSender(address taskCreator) internal view returns (address dedicated) {
        (dedicated, ) = opsProxyFactory().getProxyOf(taskCreator);
    }

    function opsProxyFactory() internal view returns (IOpsProxyFactory) {
        return IOpsProxyFactory(GELATO_PROXY_MODULE.opsProxyFactory());
    }
}
