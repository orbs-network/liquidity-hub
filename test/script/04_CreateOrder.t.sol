// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {CreateOrder, Order} from "script/04_CreateOrder.s.sol";

contract CreateOrderTest is BaseTest {
    function test_CreateOrder() public {
        address swapper = makeAddr("swapper");
        address inToken = makeAddr("inToken");
        address outToken = makeAddr("outToken");
        uint256 inAmount = 123456789;
        uint256 outAmount = 987654321;

        vm.setEnv("LH_RFQ_SWAPPER", vm.toString(swapper));
        vm.setEnv("LH_RFQ_INTOKEN", vm.toString(inToken));
        vm.setEnv("LH_RFQ_OUTTOKEN", vm.toString(outToken));
        vm.setEnv("LH_RFQ_INAMOUNT", vm.toString(inAmount));
        vm.setEnv("LH_RFQ_OUTAMOUNT", vm.toString(outAmount));
        CreateOrder script = new CreateOrder();
        script.initTestConfig();

        Order memory result = script.run();
        assertEq(result.encoded, abi.encode(result.order));
        assertEq(result.order.info.swapper, swapper);
        assertEq(address(result.order.input.token), inToken);
        assertGt(abi.encode(result.permitData).length, 100);
    }
}
