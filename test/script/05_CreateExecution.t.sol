// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {LiquidityHub, BaseTest} from "test/base/BaseTest.sol";

import {CreateExecution, Order, RFQ} from "script/05_CreateExecution.s.sol";

contract CreateExecutionTest is BaseTest {
    function test_CreateExecution() public {
        CreateExecution script = new CreateExecution();
        script.initTestConfig();

        (address to, bytes memory data) = script.run();
        assertGt(data.length, 100);
        (,, LiquidityHub executor,,,,) = script.config();
        assertEq(to, address(executor));
    }
}
