// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BaseTest} from "test/base/BaseTest.sol";

import {OrderLib} from "src/reactor/OrderLib.sol";
import {ResolutionLib} from "src/reactor/ResolutionLib.sol";

contract ResolutionHarness {
    function callResolve(OrderLib.CosignedOrder memory co) external pure returns (uint256) {
        return ResolutionLib.resolveOutAmount(co);
    }
}

contract ResolutionLibTest is BaseTest {
    ResolutionHarness harness;

    function setUp() public override {
        super.setUp();
        harness = new ResolutionHarness();
    }

    function baseCosigned() internal view returns (OrderLib.CosignedOrder memory co) {
        OrderLib.Order memory o;
        o.info.swapper = signer;
        o.input.token = address(token);
        o.input.amount = 1_000; // chunk
        o.input.maxAmount = 2_000;
        o.output.token = address(token);
        o.output.amount = 1_200; // limit
        o.output.maxAmount = 10_000; // trigger
        o.slippage = 100; // 1%

        co.order = o;
        co.cosignatureData.input = OrderLib.CosignedValue({token: o.input.token, value: 100, decimals: 18});
        co.cosignatureData.output = OrderLib.CosignedValue({token: o.output.token, value: 200, decimals: 18});
    }

    function test_resolve_amount_ok() public {
        OrderLib.CosignedOrder memory co = baseCosigned();
        // cosignedOutput = 1000 * 200 / 100 = 2000
        // minOut = 2000 * (10000-100)/10000 = 1980
        // final = max(limit 1200, 1980) = 1980
        uint256 outAmt = harness.callResolve(co);
        assertEq(outAmt, 1_980);
    }

    function test_revert_cosigned_exceeds_max() public {
        OrderLib.CosignedOrder memory co = baseCosigned();
        co.order.output.maxAmount = 1_500; // cosignedOutput is 2000 > 1500
        vm.expectRevert(ResolutionLib.CosignedMaxAmount.selector);
        harness.callResolve(co);
    }
}
