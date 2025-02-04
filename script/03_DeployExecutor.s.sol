// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {Executor, IReactor, IAllowed} from "src/Executor.sol";

contract DeployExecutor is BaseScript {
    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");
        address admin = vm.envAddress("ADMIN");
        bytes32 salt = vm.envOr("SALT", bytes32(0));
        executor = vm.envAddress("EXECUTOR");

        console.logBytes32(
            hashInitCode(type(Executor).creationCode, abi.encode(Consts.MULTICALL_ADDRESS, reactor, admin))
        );

        if (executor.code.length == 0) {
            vm.broadcast();
            Executor deployed =
                new Executor{salt: salt}(Consts.MULTICALL_ADDRESS, IReactor(payable(reactor)), IAllowed(address(admin)));
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }
}
