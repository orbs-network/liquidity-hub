// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IEIP712} from "src/interface/IEIP712.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {ReactorConstants} from "src/reactor/Constants.sol";

library CosignatureLib {
    error InvalidCosignature();
    error InvalidCosignatureNonce();
    error InvalidCosignatureInputToken();
    error InvalidCosignatureOutputToken();
    error InvalidCosignatureZeroInputValue();
    error InvalidCosignatureZeroOutputValue();
    error StaleCosignature();

    function validate(OrderLib.CosignedOrder memory cosigned, bytes32 orderHash, address cosigner, address eip712)
        internal
        view
    {
        if (cosigned.cosignatureData.timestamp + ReactorConstants.COSIGNATURE_FRESHNESS < block.timestamp) {
            revert StaleCosignature();
        }
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
}
