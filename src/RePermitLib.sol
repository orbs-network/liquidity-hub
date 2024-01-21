// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

library RePermitLib {
    struct RePermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct TransferRequest {
        address to;
        uint256 amount;
    }

    string internal constant REPERMIT_WITNESS_TRANSFER_FROM_TYPE =
        "RePermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";
    bytes32 internal constant TOKEN_PERMISSIONS_TYPE_HASH = keccak256(bytes(TOKEN_PERMISSIONS_TYPE));

    function hashWithWitness(
        RePermitTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeString,
        address spender
    ) internal pure returns (bytes32) {
        bytes32 typehash = keccak256(abi.encodePacked(REPERMIT_WITNESS_TRANSFER_FROM_TYPE, witnessTypeString));
        return keccak256(
            abi.encode(
                typehash,
                keccak256(abi.encode(TOKEN_PERMISSIONS_TYPE_HASH, permit.permitted)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }
}

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
