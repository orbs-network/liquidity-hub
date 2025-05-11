// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";
import {Executor, IReactor, IAllowed} from "src/executor/Executor.sol";

contract DeployExecutor is BaseScript {
    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");
        address admin = vm.envAddress("ADMIN");
        bytes32 salt = vm.envOr("SALT", bytes32(0));
        executor = vm.envAddress("EXECUTOR");
        address multicall = vm.envAddress("MULTICALL");

        console.logBytes32(hashInitCode(type(Executor).creationCode, abi.encode(multicall, reactor, admin)));

        if (executor.code.length == 0) {
            vm.broadcast();
            Executor deployed =
                new Executor{salt: salt}(multicall, IReactor(payable(reactor)), IAllowed(address(admin)));
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }
}
