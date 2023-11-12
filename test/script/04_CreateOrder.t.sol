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
        rfq.inAmount = 1000;
        rfq.outAmount = 900;

        vm.setEnv("LH_SWAPPER", vm.toString(rfq.swapper));
        vm.setEnv("LH_INTOKEN", vm.toString(rfq.inToken));
        vm.setEnv("LH_OUTTOKEN", vm.toString(rfq.outToken));
        vm.setEnv("LH_INAMOUNT", vm.toString(rfq.inAmount));
        vm.setEnv("LH_OUTAMOUNT", vm.toString(rfq.outAmount));

        CreateOrder script = new CreateOrder();
        script.initTestConfig();

        Order memory result = script.run();

        assertEq(result.encoded, abi.encode(result.order));
        assertEq(result.order.info.swapper, rfq.swapper);
        assertEq(address(result.order.input.token), rfq.inToken);
        assertGt(abi.encode(result.permitData).length, 100);
    }
}
