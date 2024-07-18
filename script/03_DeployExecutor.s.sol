// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract DeployExecutor is BaseScript {
    function run() public returns (address executor) {
        executor = computeCreate2Address(
            0, hashInitCode(type(LiquidityHub).creationCode, abi.encode(config.reactor, config.admin))
        );

        if (executor.code.length == 0) {
            vm.broadcast();
            LiquidityHub deployed = new LiquidityHub{salt: 0}(config.reactor, config.admin);
            require(executor == address(deployed), "mismatched address");
        } else {
            console.log("already deployed");
        }
    }
}
