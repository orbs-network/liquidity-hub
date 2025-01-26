// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";

contract DeployAdmin is BaseScript {
    function run() public returns (address admin) {
        address owner = vm.envAddress("OWNER");
        address weth = vm.envAddress("WETH");
        bytes32 salt = vm.envOr("SALT", bytes32(uint256(0x9563)));
        admin = vm.envAddress("ADMIN");

        bytes32 initCodeHash = hashInitCode(type(Admin).creationCode, abi.encode(owner));
        console.logBytes32(initCodeHash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: salt}(owner);
            admin = address(deployed);

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            require(Admin(payable(admin)).owner() == owner, "admin mismatched owner");
            console.log("admin already deployed");
        }
    }
}
