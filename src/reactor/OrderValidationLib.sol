// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OrderLib} from "src/reactor/OrderLib.sol";

library OrderValidationLib {
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_SLIPPAGE = BPS / 2;

    function validateOrder(OrderLib.Order memory order) internal pure {
        if (order.input.amount == 0) revert OrderLib.InvalidOrderInputAmountZero();
        if (order.input.amount > order.input.maxAmount) revert OrderLib.InvalidOrderInputAmountGtMax();
        if (order.output.amount > order.output.maxAmount) revert OrderLib.InvalidOrderOutputAmountGtMax();
        if (order.slippage >= MAX_SLIPPAGE) revert OrderLib.InvalidOrderSlippageTooHigh();
        if (order.input.token == address(0)) revert OrderLib.InvalidOrderInputTokenZero();
    }
}
