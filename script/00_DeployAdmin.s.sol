// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";

contract DeployAdmin is BaseScript {
    function run() public returns (address admin) {
        address deployer = vm.envAddress("DEPLOYER");
        address weth = vm.envAddress("WETH");

        admin = computeCreate2Address(0, hashInitCode(type(Admin).creationCode, abi.encode(deployer)));

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: 0}(deployer);

            require(admin == address(deployed), "mismatched address");

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            console.log("already deployed");
        }
    }
}
