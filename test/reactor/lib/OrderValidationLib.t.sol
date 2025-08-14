// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BaseTest} from "test/base/BaseTest.sol";

import {OrderLib} from "src/reactor/OrderLib.sol";
import {OrderValidationLib} from "src/reactor/OrderValidationLib.sol";

contract OrderValidationHarness {
    function callValidate(OrderLib.Order memory order) external pure {
        OrderValidationLib.validateOrder(order);
    }
}

contract OrderValidationLibTest is BaseTest {
    OrderValidationHarness harness;

    function setUp() public override {
        super.setUp();
        harness = new OrderValidationHarness();
    }

    function baseOrder() internal view returns (OrderLib.Order memory o) {
        o.info.swapper = signer;
        o.input.token = address(token);
        o.input.amount = 100;
        o.input.maxAmount = 200;
        o.output.token = address(token);
        o.output.amount = 50;
        o.output.maxAmount = 100;
        o.slippage = 100; // 1%
    }

    function test_validate_ok() public {
        OrderLib.Order memory o = baseOrder();
        harness.callValidate(o);
    }

    function test_revert_zero_input_amount() public {
        OrderLib.Order memory o = baseOrder();
        o.input.amount = 0;
        vm.expectRevert(OrderLib.InvalidOrderInputAmountZero.selector);
        harness.callValidate(o);
    }

    function test_revert_input_gt_max() public {
        OrderLib.Order memory o = baseOrder();
        o.input.amount = 201;
        vm.expectRevert(OrderLib.InvalidOrderInputAmountGtMax.selector);
        harness.callValidate(o);
    }

    function test_revert_output_gt_max() public {
        OrderLib.Order memory o = baseOrder();
        o.output.amount = 101;
        vm.expectRevert(OrderLib.InvalidOrderOutputAmountGtMax.selector);
        harness.callValidate(o);
    }

    function test_revert_slippage_too_high() public {
        OrderLib.Order memory o = baseOrder();
        o.slippage = 5000; // >= BPS/2
        vm.expectRevert(OrderLib.InvalidOrderSlippageTooHigh.selector);
        harness.callValidate(o);
    }

    function test_revert_zero_token() public {
        OrderLib.Order memory o = baseOrder();
        o.input.token = address(0);
        vm.expectRevert(OrderLib.InvalidOrderInputTokenZero.selector);
        harness.callValidate(o);
    }
}
