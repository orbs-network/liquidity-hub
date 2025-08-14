// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";
import {RePermit} from "src/repermit/RePermit.sol";

contract DeployRepermit is BaseScript {
    function run() public returns (address repermit) {
        bytes32 hash = hashInitCode(type(RePermit).creationCode);
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        repermit = computeCreate2Address(salt, hash);

        if (repermit.code.length == 0) {
            vm.broadcast();
            RePermit deployed = new RePermit{salt: salt}();
            require(repermit == address(deployed), "repermit mismatched address");
        } else {
            console.log("repermit already deployed");
        }
    }
}
