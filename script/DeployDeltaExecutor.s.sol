// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";
import {DeltaExecutor} from "src/executor/DeltaExecutor.sol";

contract DeployDeltaExecutor is BaseScript {
    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");

        address[] memory allowed = new address[](2);
        allowed[0] = 0x1b6c933C4A855C9F4Ad1AFBD05EB3f51dbB83CF8;
        allowed[1] = 0x0000000000bbF5c5Fd284e657F01Bd000933C96D;

        bytes32 hash = hashInitCode(type(DeltaExecutor).creationCode, abi.encode(reactor, allowed));
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        executor = computeCreate2Address(salt, hash);

        if (executor.code.length == 0) {
            vm.broadcast();
            DeltaExecutor deployed = new DeltaExecutor{salt: salt}(reactor, allowed);
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }
}
