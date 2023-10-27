// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {DeployTreasury} from "script/01_DeployTreasury.s.sol";

contract DeployTreasuryTest is BaseTest {
    function test_Deploy() public {
        DeployTreasury script = new DeployTreasury();
        address result = script.run();
        assertNotEq(result, address(0));
    }
}
