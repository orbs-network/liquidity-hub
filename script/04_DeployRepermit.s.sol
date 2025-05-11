// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";
import {RePermit} from "src/repermit/RePermit.sol";

contract DeployRepermit is BaseScript {
    function run() public returns (address repermit) {
        repermit = computeCreate2Address(0, hashInitCode(type(RePermit).creationCode));

        if (repermit.code.length == 0) {
            vm.broadcast();
            require(repermit == address(new RePermit{salt: 0}()), "repermit mismatched address");
        } else {
            console.log("repermit already deployed");
        }
    }
}
