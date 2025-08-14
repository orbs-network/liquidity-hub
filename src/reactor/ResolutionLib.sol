// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

library ResolutionLib {
    using Math for uint256;

    uint256 public constant BPS = 10_000;

    error CosignedMaxAmount();

    function resolveOutAmount(OrderLib.CosignedOrder memory cosigned) internal pure returns (uint256 outAmount) {
        uint256 cosignedOutput = cosigned.order.input.amount.mulDiv(
            cosigned.cosignatureData.output.value, cosigned.cosignatureData.input.value
        );
        if (cosignedOutput > cosigned.order.output.maxAmount) revert CosignedMaxAmount();

        uint256 minOut = cosignedOutput.mulDiv(BPS - cosigned.order.slippage, BPS);
        outAmount = minOut.max(cosigned.order.output.amount);
    }
}
