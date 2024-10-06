// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";

contract DeployAdmin is BaseScript {
    bytes32 public constant SALT = bytes32(uint256(0x9563));

    function run() public returns (address admin) {
        address deployer = vm.envAddress("DEPLOYER");
        address weth = vm.envAddress("WETH");

        bytes32 initCodeHash = hashInitCode(type(Admin).creationCode, abi.encode(deployer));
        console.logBytes32(initCodeHash);
        admin = computeCreate2Address(SALT, initCodeHash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: SALT}(deployer);

            require(admin == address(deployed), "mismatched address");

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            console.log("already deployed");
        }
    }
}
