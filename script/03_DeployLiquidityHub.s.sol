// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract DeployLiquidityHub is BaseScript {
    function run() public returns (address result) {
        vm.broadcast(deployer);
        result = address(new LiquidityHub{salt: 0x00}(config.reactor, config.treasury));
        vm.label(result, "LiquidityHub");
        console2.log("LiquidityHub deployed:", result);
    }
}
