// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {Admin} from "src/Admin.sol";

contract DeployAdmin is BaseScript {
    function run() public returns (address admin) {
        address owner = vm.envAddress("OWNER");
        address weth = vm.envAddress("WETH");
        address multicall = vm.envAddress("MULTICALL");

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        bytes32 hash = hashInitCode(type(Admin).creationCode, abi.encode(owner));
        console.logBytes32(hash);

        admin = computeCreate2Address(salt, hash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: salt}(owner);
            admin = address(deployed);

            vm.broadcast();
            deployed.init(multicall, weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            require(Admin(payable(admin)).owner() == owner, "admin mismatched owner");
            console.log("admin already deployed");
        }
    }
}
