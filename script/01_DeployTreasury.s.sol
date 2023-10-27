// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {Treasury} from "src/Treasury.sol";

contract DeployTreasury is Base {
    function run() public returns (address result) {
        vm.broadcast(deployer);
        Treasury treasury = new Treasury{salt: 0}(config.weth, deployer);
        result = address(treasury);
        vm.label(result, "Treasury");
        console2.log("Treasury deployed:", result);
    }
}
