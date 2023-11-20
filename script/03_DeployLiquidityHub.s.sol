// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract DeployLiquidityHub is Base {
    function run() public returns (address executor) {
        vm.broadcast(deployer);
        executor = address(new LiquidityHub{salt: 0}(config.reactor, config.treasury));
    }
}
