// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";

contract DeployAdmin is BaseScript {
    function run(address owner, address weth) public returns (address admin) {
        admin = computeCreate2Address(0, hashInitCode(type(Admin).creationCode, abi.encode(owner)));

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: 0}(owner);
            
            require(admin == address(deployed), "mismatched address");

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            console.log("already deployed");
        }
    }
}
