// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {OrderValidationLib} from "src/reactor/OrderValidationLib.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {ReactorConstants} from "src/reactor/Constants.sol";

contract OrderValidationLibFuzzTest is Test {
    function testFuzz_validate_ok(
        address swapper,
        address inToken,
        address outToken,
        address recipient,
        uint256 inAmount,
        uint256 maxAmount,
        uint256 minOut,
        uint256 maxOut,
        uint256 slippage
    ) external {
        vm.assume(swapper != address(0));
        vm.assume(inToken != address(0));
        vm.assume(recipient != address(0));
        vm.assume(inAmount > 0);
        vm.assume(maxAmount >= inAmount);
        vm.assume(maxOut >= minOut);
        vm.assume(slippage < ReactorConstants.MAX_SLIPPAGE);

        OrderLib.Order memory o;
        o.info.swapper = swapper;
        o.input.token = inToken;
        o.input.amount = inAmount;
        o.input.maxAmount = maxAmount;
        o.output.token = outToken;
        o.output.amount = minOut;
        o.output.maxAmount = maxOut;
        o.output.recipient = recipient;
        o.slippage = slippage;

        OrderValidationLib.validate(o);
    }
}
