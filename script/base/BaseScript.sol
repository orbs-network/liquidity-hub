// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LiquidityHub, IReactor} from "src/executor/LiquidityHub.sol";
import {IEIP712} from "src/repermit/RePermit.sol";
import {OrderLib, RePermit, RePermitLib, OrderReactor} from "src/reactor/OrderReactor.sol";
import {Admin, IWETH, IMulticall3, IERC20} from "src/Admin.sol";

abstract contract BaseScript is Script {
    function setUp() public virtual {}

    function signPermit2(address permit2, uint256 privateKey, bytes32 orderHash)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 msgHash = ECDSA.toTypedDataHash(IEIP712(permit2).DOMAIN_SEPARATOR(), orderHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function signRePermit(address repermit, uint256 privateKey, OrderLib.Order memory order, address spender)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 msgHash = ECDSA.toTypedDataHash(
            IEIP712(repermit).DOMAIN_SEPARATOR(),
            RePermitLib.hashWithWitness(
                RePermitLib.RePermitTransferFrom(
                    RePermitLib.TokenPermissions(address(order.input.token), order.input.amount),
                    order.info.nonce,
                    order.info.deadline
                ),
                PartialOrderLib.hash(order),
                PartialOrderLib.WITNESS_TYPE,
                spender
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }
}
