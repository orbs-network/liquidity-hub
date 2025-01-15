// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {LiquidityHub, IReactor, IAllowed} from "src/LiquidityHub.sol";

contract DeployExecutor is BaseScript {
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
