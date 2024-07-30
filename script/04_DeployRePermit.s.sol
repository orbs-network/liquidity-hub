// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {RePermit} from "src/RePermit.sol";
import {BaseScript, Consts} from "script/base/BaseScript.sol";

contract DeployRePermit is BaseScript {
    function run() public returns (address repermit) {
        repermit = computeCreate2Address(0, hashInitCode(type(RePermit).creationCode));

        if (repermit.code.length == 0) {
            vm.broadcast();
            require(repermit == address(new RePermit{salt: 0}()), "mismatched address");
        } else {
            console.log("already deployed");
        }
    }
}
