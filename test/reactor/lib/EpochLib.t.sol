// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {EpochLib} from "src/reactor/EpochLib.sol";

contract EpochHarness {
    mapping(bytes32 => uint256) public epochs;

    function callValidateAndUpdate(bytes32 hash, uint256 epochSeconds) external {
        EpochLib.validateAndUpdate(epochs, hash, epochSeconds);
    }
}

contract EpochLibTest is Test {
    EpochHarness harness;
    bytes32 constant H = keccak256("h");

    function setUp() public {
        harness = new EpochHarness();
    }

    function test_epoch_zero_allows_once() public {
        harness.callValidateAndUpdate(H, 0);
        vm.expectRevert(EpochLib.InvalidEpoch.selector);
        harness.callValidateAndUpdate(H, 0);
    }

    function test_epoch_interval_progression() public {
        uint256 interval = 60;
        // first call ok at t=block.timestamp/60=0
        harness.callValidateAndUpdate(H, interval);
        // immediate second should revert since current(0) < stored(1)
        vm.expectRevert(EpochLib.InvalidEpoch.selector);
        harness.callValidateAndUpdate(H, interval);

        // advance to next epoch (current=1) -> ok
        vm.warp(block.timestamp + interval);
        harness.callValidateAndUpdate(H, interval);
    }
}
