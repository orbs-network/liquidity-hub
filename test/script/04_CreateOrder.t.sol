// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {CreateOrder, Order, RFQ} from "script/04_CreateOrder.s.sol";

contract CreateOrderTest is BaseTest {
    function test_CreateOrder() public {
        RFQ memory rfq;
        rfq.swapper = makeAddr("swapper");
        rfq.inToken = makeAddr("inToken");
        rfq.outToken = makeAddr("outToken");
        rfq.inAmount = 123456789;
        rfq.outAmount = 987654321;

        vm.setEnv("LH_RFQ", vm.toString(abi.encode(rfq)));
        CreateOrder script = new CreateOrder();
        script.initTestConfig();

        Order memory result = script.run();
        assertEq(result.encoded, abi.encode(result.order));
        assertEq(result.order.info.swapper, rfq.swapper);
        assertEq(address(result.order.input.token), rfq.inToken);
        assertGt(abi.encode(result.permitData).length, 100);
    }
}
