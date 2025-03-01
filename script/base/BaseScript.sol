// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Admin, IWETH, Consts, IMulticall3, IERC20} from "src/Admin.sol";
import {PartialOrderLib, RePermit, RePermitLib, PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {IEIP712} from "src/RePermit.sol";
import {Permit2Lib} from "src/Permit2Lib.sol";

struct Config {
    Admin admin;
    LiquidityHub executor;
    IReactor reactor;
    IReactor reactor2;
    PartialOrderReactor reactorPartial;
    RePermit repermit;
}

abstract contract BaseScript is Script {
    Config public config;

    function setUp() public virtual {}

    function signPermit2(uint256 privateKey, bytes32 orderHash) internal view returns (bytes memory sig) {
        bytes32 msgHash = ECDSA.toTypedDataHash(IEIP712(Consts.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(), orderHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function signRePermit(uint256 privateKey, PartialOrderLib.PartialOrder memory order)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 msgHash = ECDSA.toTypedDataHash(
            config.repermit.DOMAIN_SEPARATOR(),
            RePermitLib.hashWithWitness(
                RePermitLib.RePermitTransferFrom(
                    Permit2Lib.TokenPermissions(address(order.input.token), order.input.amount),
                    order.info.nonce,
                    order.info.deadline
                ),
                PartialOrderLib.hash(order),
                PartialOrderLib.WITNESS_TYPE,
                address(config.reactorPartial)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }
}
