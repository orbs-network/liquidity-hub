// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract CreateOrder is Base {
    function run() public {
        vm.broadcast(deployer);
    }
}
