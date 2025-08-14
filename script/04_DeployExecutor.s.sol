// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";
import {Executor, IReactor, IAllowed} from "src/executor/Executor.sol";

contract DeployExecutor is BaseScript {
    function run() public returns (address executor) {
        address multicall = vm.envAddress("MULTICALL");
        address reactor = vm.envAddress("REACTOR");
        address admin = vm.envAddress("ADMIN");

        bytes32 hash = hashInitCode(type(Executor).creationCode, abi.encode(multicall, reactor, admin));
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        executor = computeCreate2Address(salt, hash);

        if (executor.code.length == 0) {
            vm.broadcast();
            Executor deployed = new Executor{salt: salt}(multicall, reactor, admin);
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }
}
