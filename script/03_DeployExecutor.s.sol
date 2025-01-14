// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {LiquidityHub, IReactor, IAllowed} from "src/LiquidityHub.sol";

contract DeployExecutor is BaseScript {
    //executorPCSX = _executor(0x35db01D1425685789dCc9228d47C7A5C049388d8, 0x000066320a467dE62B1548f46465abBB82662331);

    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");
        address admin = vm.envAddress("ADMIN");

        executor = computeCreate2Address(0, hashInitCode(type(LiquidityHub).creationCode, abi.encode(reactor, admin)));

        if (executor.code.length == 0) {
            vm.broadcast();
            LiquidityHub deployed = new LiquidityHub{salt: 0}(IReactor(payable(reactor)), IAllowed(address(admin)));
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }
}
