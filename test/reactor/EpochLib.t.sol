// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {EpochLib} from "src/reactor/EpochLib.sol";

contract EpochLibTest is Test {
    mapping(bytes32 => uint256) internal epochs;

    function callEpoch(bytes32 h, uint256 interval) external {
        EpochLib.update(epochs, h, interval);
    }

    function test_epoch_zero_allows_once() public {
        bytes32 h = keccak256("h");
        this.callEpoch(h, 0);
        vm.expectRevert(EpochLib.InvalidEpoch.selector);
        this.callEpoch(h, 0);
    }

    function test_epoch_interval_progression() public {
        bytes32 h = keccak256("h");
        uint256 interval = 60;
        this.callEpoch(h, interval);
        vm.expectRevert(EpochLib.InvalidEpoch.selector);
        this.callEpoch(h, interval);
        vm.warp(block.timestamp + interval);
        this.callEpoch(h, interval);
    }
}
