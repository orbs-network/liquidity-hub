// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";

contract DeployPartial is BaseScript {
    function run() public returns (address reactorPartial) {
        address repermit = vm.envAddress("REPERMIT");

        reactorPartial =
            computeCreate2Address(0, hashInitCode(type(PartialOrderReactor).creationCode, abi.encode(repermit)));

        if (reactorPartial.code.length == 0) {
            vm.broadcast();
            PartialOrderReactor deployed = new PartialOrderReactor{salt: 0}(RePermit(repermit));
            require(reactorPartial == address(deployed), "mismatched address");
        } else {
            console.log("partialreactor already deployed");
        }
    }
}
