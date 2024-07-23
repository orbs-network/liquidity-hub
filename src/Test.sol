// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

contract Test {
    function test() public view returns (uint256, uint256, uint256, uint256) {
        return (block.number, block.timestamp, block.gaslimit, gasleft());
    }
}
