// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

library Call {
    error RawCallFailedWithNoReason();

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool _ok, bytes memory _data) = target.call(data);

        if (!_ok) _revert(_data);

        return _data;
    }

    function _revert(bytes memory data) private pure {
        if (data.length == 0) revert RawCallFailedWithNoReason();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
