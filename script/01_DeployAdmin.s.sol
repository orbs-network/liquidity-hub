// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {Admin} from "src/Admin.sol";

contract DeployAdmin is Base {
    function run(address owner) public returns (address admin) {
        admin = computeCreate2Address(0, hashInitCode(type(Admin).creationCode, abi.encode(owner)));

        if (admin.code.length == 0) {
            vm.broadcast(deployer);
            Admin deployed = new Admin{salt: 0}(owner);
            
            require(admin == address(deployed), "mismatched address");

            vm.broadcast(deployer);
            deployed.initialize(address(config.weth));
        } else {
            require(Admin(admin).weth() != address(0), "not initialized");
            console.log("already deployed");
        }
    }
}
