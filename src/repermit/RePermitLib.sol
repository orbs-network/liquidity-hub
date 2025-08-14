// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library RePermitLib {
    struct RePermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TransferRequest {
        address to;
        uint256 amount;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    event Cancel(address indexed signer, uint256 nonce);

    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";
    bytes32 internal constant TOKEN_PERMISSIONS_TYPE_HASH = keccak256(bytes(TOKEN_PERMISSIONS_TYPE));
    string internal constant REPERMIT_WITNESS_TRANSFER_FROM_TYPE_PREFIX =
        "RePermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";

    function hashWithWitness(
        RePermitTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeSuffix,
        address spender
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(bytes(string.concat(REPERMIT_WITNESS_TRANSFER_FROM_TYPE_PREFIX, witnessTypeSuffix))),
                keccak256(abi.encode(TOKEN_PERMISSIONS_TYPE_HASH, permit.permitted)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }
}
