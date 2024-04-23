// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.19;

library Decoder {
    function calldataDecode(bytes memory data) internal pure returns (bytes4 selector, bytes memory args) {
        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            selector := mload(add(data, 0x20))

            let totalLength := mload(data)
            let targetLength := sub(totalLength, 4)
            args := mload(0x40)

            // Set the length of callDataWithoutSelector (initial length - 4)
            mstore(args, targetLength)

            // Mark the memory space taken for callDataWithoutSelector as allocated
            mstore(0x40, add(args, add(0x20, targetLength)))

            // Process first 32 bytes (we only take the last 28 bytes)
            mstore(add(args, 0x20), shl(0x20, mload(add(data, 0x20))))

            // Process all other data by chunks of 32 bytes
            for {
                let i := 0x1C
            } lt(i, targetLength) {
                i := add(i, 0x20)
            } {
                mstore(add(add(args, 0x20), i), mload(add(add(data, 0x20), add(i, 0x04))))
            }
        }
    }
}
