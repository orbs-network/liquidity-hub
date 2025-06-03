// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IEIP712, RePermitLib} from "src/repermit/RePermit.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

abstract contract BaseScript is Script {
    function setUp() public virtual {}

    function signEIP712(address permit, uint256 privateKey, bytes32 hash) internal view returns (bytes memory sig) {
        bytes32 msgHash = ECDSA.toTypedDataHash(IEIP712(permit).DOMAIN_SEPARATOR(), hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function hashRePermit(OrderLib.Order memory order, address spender) internal view returns (bytes32) {
        return RePermitLib.hashWithWitness(
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(order.input.token, order.input.maxAmount),
                order.info.nonce,
                order.info.deadline
            ),
            OrderLib.hash(order),
            OrderLib.WITNESS_TYPE,
            spender
        );
    }
}
