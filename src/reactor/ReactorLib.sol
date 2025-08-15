// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IEIP712} from "src/interface/IEIP712.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

library ReactorLib {
    using Math for uint256;

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_SLIPPAGE = BPS / 2;
    uint256 public constant COSIGNATURE_FRESHNESS = 1 minutes;

    error InvalidEpoch();
    error InvalidCosignature();
    error InvalidCosignatureNonce();
    error InvalidCosignatureInputToken();
    error InvalidCosignatureOutputToken();
    error InvalidCosignatureZeroInputValue();
    error InvalidCosignatureZeroOutputValue();
    error StaleCosignature();
    error CosignedMaxAmount();
    error InvalidOrderInputAmountZero();
    error InvalidOrderInputAmountGtMax();
    error InvalidOrderOutputAmountGtMax();
    error InvalidOrderSlippageTooHigh();
    error InvalidOrderInputTokenZero();
    error InvalidOrderOutputRecipientZero();

    // Epoch validation and update
    function validateAndUpdate(mapping(bytes32 => uint256) storage epochs, bytes32 hash, uint256 epochSeconds)
        internal
    {
        uint256 current = epochSeconds == 0 ? 0 : block.timestamp / epochSeconds;
        if (current < epochs[hash]) revert InvalidEpoch();
        epochs[hash] = current + 1;
    }

    // Order validation
    function validateOrder(OrderLib.Order memory order) internal pure {
        if (order.input.amount == 0) revert InvalidOrderInputAmountZero();
        if (order.input.amount > order.input.maxAmount) revert InvalidOrderInputAmountGtMax();
        if (order.output.amount > order.output.maxAmount) revert InvalidOrderOutputAmountGtMax();
        if (order.slippage >= MAX_SLIPPAGE) revert InvalidOrderSlippageTooHigh();
        if (order.input.token == address(0)) revert InvalidOrderInputTokenZero();
        if (order.output.recipient == address(0)) revert InvalidOrderOutputRecipientZero();
    }

    // Cosignature validation
    function validateCosignature(
        OrderLib.CosignedOrder memory cosigned,
        bytes32 orderHash,
        address cosigner,
        address eip712
    ) internal view {
        if (cosigned.cosignatureData.timestamp + COSIGNATURE_FRESHNESS < block.timestamp) revert StaleCosignature();
        if (cosigned.cosignatureData.nonce != orderHash) revert InvalidCosignatureNonce();
        if (cosigned.cosignatureData.input.token != cosigned.order.input.token) revert InvalidCosignatureInputToken();
        if (cosigned.cosignatureData.output.token != cosigned.order.output.token) {
            revert InvalidCosignatureOutputToken();
        }
        if (cosigned.cosignatureData.input.value == 0) revert InvalidCosignatureZeroInputValue();
        if (cosigned.cosignatureData.output.value == 0) revert InvalidCosignatureZeroOutputValue();

        bytes32 digest = IEIP712(eip712).hashTypedData(OrderLib.hash(cosigned.cosignatureData));
        if (!SignatureChecker.isValidSignatureNow(cosigner, digest, cosigned.cosignature)) revert InvalidCosignature();
    }

    // Resolution helpers
    function resolveOutAmount(OrderLib.CosignedOrder memory cosigned) internal pure returns (uint256 outAmount) {
        uint256 cosignedOutput = cosigned.order.input.amount.mulDiv(
            cosigned.cosignatureData.output.value, cosigned.cosignatureData.input.value
        );
        if (cosignedOutput > cosigned.order.output.maxAmount) revert CosignedMaxAmount();

        uint256 minOut = cosignedOutput.mulDiv(BPS - cosigned.order.slippage, BPS);
        outAmount = minOut.max(cosigned.order.output.amount);
    }
}
