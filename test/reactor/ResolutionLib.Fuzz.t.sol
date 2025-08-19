// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {ResolutionLib} from "src/reactor/ResolutionLib.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {ReactorConstants} from "src/reactor/Constants.sol";

contract ResolutionLibFuzzTest is Test {
    function callResolve(OrderLib.CosignedOrder memory co) external pure returns (uint256) {
        return ResolutionLib.resolveOutAmount(co);
    }

    function testFuzz_resolveOutAmount_bounds(
        uint256 inAmount,
        uint256 limit,
        uint256 maxOut,
        uint256 inputValue,
        uint256 outputValue,
        uint256 slippage
    ) external {
        vm.assume(inAmount > 0 && inAmount < type(uint128).max);
        vm.assume(limit < type(uint128).max);
        vm.assume(maxOut > 0 && maxOut < type(uint128).max);
        vm.assume(inputValue > 0 && outputValue > 0 && inputValue < 1e36 && outputValue < 1e36);
        vm.assume(slippage < ReactorConstants.MAX_SLIPPAGE);

        OrderLib.CosignedOrder memory co;
        co.order.input.amount = inAmount;
        co.order.output.amount = limit;
        co.order.output.maxAmount = maxOut;
        co.order.slippage = slippage;
        co.cosignatureData.input = OrderLib.CosignedValue({token: address(1), value: inputValue, decimals: 18});
        co.cosignatureData.output = OrderLib.CosignedValue({token: address(2), value: outputValue, decimals: 18});

        uint256 cosignedOutput = (inAmount * outputValue) / inputValue;
        if (cosignedOutput > maxOut) {
            vm.expectRevert(ResolutionLib.CosignedMaxAmount.selector);
            this.callResolve(co);
            return;
        }

        uint256 minOut = (cosignedOutput * (ReactorConstants.BPS - slippage)) / ReactorConstants.BPS;
        uint256 expected = minOut > limit ? minOut : limit;
        uint256 outAmt = this.callResolve(co);
        assertEq(outAmt, expected);
    }
}
