// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";
import {BaseScript, Consts} from "script/base/BaseScript.sol";

contract DeployPartialOrderReactor is BaseScript {
    function run() public returns (address reactor) {
        reactor =
            computeCreate2Address(0, hashInitCode(type(PartialOrderReactor).creationCode, abi.encode(config.repermit)));

        if (reactor.code.length == 0) {
            vm.broadcast();
            PartialOrderReactor deployed = new PartialOrderReactor{salt: 0}(config.repermit);
            require(reactor == address(deployed), "mismatched address");
        } else {
            console.log("already deployed");
        }
    }
}
