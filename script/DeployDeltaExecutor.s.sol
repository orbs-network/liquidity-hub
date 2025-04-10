// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {DeltaExecutor} from "src/DeltaExecutor.sol";

contract DeployDeltaExecutor is BaseScript {
    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");
        address weth = vm.envAddress("WETH");
        address[] memory allowed = vm.envAddress("ALLOWED", ",");

        vm.broadcast();
        return address(new DeltaExecutor(reactor, weth, allowed));
    }
}
