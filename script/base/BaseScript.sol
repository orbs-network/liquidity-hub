// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IEIP712, RePermitLib} from "src/repermit/RePermit.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

abstract contract BaseScript is Script {
    function setUp() public virtual {}

    function signEIP712(address eip712, uint256 privateKey, bytes32 hash) internal view returns (bytes memory sig) {
        bytes32 msgHash = ECDSA.toTypedDataHash(IEIP712(eip712).DOMAIN_SEPARATOR(), hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function hashRePermit(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes32 witness,
        string memory witnessTypeString,
        address spender
    ) internal pure returns (bytes32) {
        return RePermitLib.hashWithWitness(
            RePermitLib.RePermitTransferFrom(RePermitLib.TokenPermissions(token, amount), nonce, deadline),
            witness,
            witnessTypeString,
            spender
        );
    }

    function hashRePermit(OrderLib.Order memory order, address spender) internal pure returns (bytes32) {
        return hashRePermit(
            order.input.token,
            order.input.maxAmount,
            order.info.nonce,
            order.info.deadline,
            OrderLib.hash(order),
            OrderLib.WITNESS_TYPE,
            spender
        );
    }
}
