// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {Treasury} from "src/Treasury.sol";

contract DeployTreasury is Base {
    function run() public {
        vm.broadcast(deployer);
        address result = address(new Treasury{salt: 0x00}(config.weth, deployer));
        vm.label(result, "Treasury");
    }
}
