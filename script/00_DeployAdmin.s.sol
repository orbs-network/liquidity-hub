// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {Admin} from "src/Admin.sol";

contract DeployAdmin is BaseScript {
    function run() public returns (address admin) {
        address owner = vm.envAddress("OWNER");

        bytes32 hash = hashInitCode(type(Admin).creationCode, abi.encode(owner));
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        admin = computeCreate2Address(salt, hash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: salt}(owner);
            admin = address(deployed);
        } else {
            require(Admin(payable(admin)).owner() == owner, "admin mismatched owner");
            require(Admin(payable(admin)).allowed(owner), "owner not allowed");
            console.log("admin already deployed");
        }
    }
}
