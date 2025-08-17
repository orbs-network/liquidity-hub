// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library EpochLib {
    error InvalidEpoch();

    function update(mapping(bytes32 => uint256) storage epochs, bytes32 hash, uint256 epoch) internal {
        uint256 current = epoch == 0 ? 0 : block.timestamp / epoch;
        if (current < epochs[hash]) revert InvalidEpoch();
        epochs[hash] = current + 1;
    }
}
