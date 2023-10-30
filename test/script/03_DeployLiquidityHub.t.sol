// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, Treasury} from "test/base/BaseTest.sol";

import {DeployLiquidityHub} from "script/03_DeployLiquidityHub.s.sol";

contract DeployLiquidityHubTest is BaseTest {
    function test_Deploy() public {
        DeployLiquidityHub script = new DeployLiquidityHub();
        script.initTestConfig();
        address result = script.run();
        assertNotEq(result, address(0));
    }
}
