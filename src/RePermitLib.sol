// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Permit2Lib} from "./Permit2Lib.sol";

library RePermitLib {
    struct RePermitTransferFrom {
        Permit2Lib.TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TransferRequest {
        address to;
        uint256 amount;
    }

    string internal constant REPERMIT_WITNESS_TRANSFER_FROM_TYPE_PREFIX =
        "RePermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";

    function hashWithWitness(
        RePermitTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeString,
        address spender
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(bytes(string.concat(REPERMIT_WITNESS_TRANSFER_FROM_TYPE_PREFIX, witnessTypeString))),
                keccak256(abi.encode(Permit2Lib.TOKEN_PERMISSIONS_TYPE_HASH, permit.permitted)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }
}
