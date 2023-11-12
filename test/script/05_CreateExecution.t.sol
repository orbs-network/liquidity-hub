// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {LiquidityHub, BaseTest} from "test/base/BaseTest.sol";

import {CreateExecution, Order, RFQ, Call} from "script/05_CreateExecution.s.sol";

contract CreateExecutionTest is BaseTest {
    function test_CreateExecution() public {
        CreateExecution script = new CreateExecution();
        script.initTestConfig();

        RFQ memory rfq;
        rfq.swapper = makeAddr("swapper");
        rfq.inToken = makeAddr("inToken");
        rfq.outToken = makeAddr("outToken");
        rfq.inAmount = 1000;
        rfq.outAmount = 900;
        Order memory order0 = createOrder(rfq);
        bytes memory sig0 = new bytes(32);

        rfq.swapper = makeAddr("swapper2");
        rfq.inToken = makeAddr("inToken2");
        rfq.outToken = makeAddr("outToken2");
        rfq.inAmount = 2000;
        rfq.outAmount = 1900;
        Order memory order1 = createOrder(rfq);
        bytes memory sig1 = new bytes(32);

        vm.setEnv("LH_ORDERS", string.concat(vm.toString(order0.encoded), ",", vm.toString(order1.encoded)));
        vm.setEnv("LH_SIGS", string.concat(vm.toString(sig0), ",", vm.toString(sig1)));

        Call[] memory calls = new Call[](1);
        calls[0].target = makeAddr("target");
        calls[0].callData = abi.encodeWithSignature("test()");

        vm.setEnv("LH_CALLS", vm.toString(abi.encode(calls)));

        (address to, bytes memory data) = script.run();
        assertGt(data.length, 100);
        (,, LiquidityHub executor,,,,) = script.config();
        assertEq(to, address(executor));
    }
}
