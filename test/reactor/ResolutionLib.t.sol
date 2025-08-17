// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {ResolutionLib} from "src/reactor/ResolutionLib.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

contract ResolutionLibTest is Test {
    function callResolve(OrderLib.CosignedOrder memory co) external pure returns (uint256) {
        return ResolutionLib.resolveOutAmount(co);
    }

    function _baseCosigned() internal returns (OrderLib.CosignedOrder memory co) {
        OrderLib.Order memory o;
        o.info.swapper = makeAddr("swapper");
        o.input.token = makeAddr("in");
        o.input.amount = 1_000; // chunk
        o.input.maxAmount = 2_000;
        o.output.token = makeAddr("out");
        o.output.amount = 1_200; // limit
        o.output.maxAmount = 10_000; // trigger
        o.slippage = 100; // 1%

        co.order = o;
        co.cosignatureData.input = OrderLib.CosignedValue({token: o.input.token, value: 100, decimals: 18});
        co.cosignatureData.output = OrderLib.CosignedValue({token: o.output.token, value: 200, decimals: 18});
    }

    function test_resolveOutAmount_ok() public {
        OrderLib.CosignedOrder memory co = _baseCosigned();
        uint256 outAmt = this.callResolve(co);
        assertEq(outAmt, 1_980);
    }

    function test_resolveOutAmount_revert_cosigned_exceeds_max() public {
        OrderLib.CosignedOrder memory co = _baseCosigned();
        co.order.output.maxAmount = 1_500; // cosignedOutput is 2000 > 1500
        vm.expectRevert(ResolutionLib.CosignedMaxAmount.selector);
        this.callResolve(co);
    }
}
