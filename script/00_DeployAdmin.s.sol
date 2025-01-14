// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin} from "script/base/BaseScript.sol";

contract DeployAdmin is BaseScript {
    //address fee00 = _admin(owner, weth, 0x55669ad6a3db66a4a3bbfe640c9faa64095a75a5228cf52464f4a449257ee6c5);
    //address fee01 = _admin(owner, weth, 0xab1462bd378a47c5676f45ed8b1f1de08ddf212e2525b6c82e7c2c11c41590d2);
    //address fee02 = _admin(owner, weth, 0x668fa19c8dfec98130ebcc64b727ecf11105987af78936a05550a1f6679b16cc);
    //address fee03 = _admin(owner, weth, 0x7622f2bb307bda72700fbabe78b8f2bc76c8d4f214e47ca34aa96b4e980947ce);

    function run() public returns (address admin) {
        address owner = vm.envAddress("OWNER");
        address weth = vm.envAddress("WETH");

        bytes32 initCodeHash = hashInitCode(type(Admin).creationCode, abi.encode(owner));
        console.logBytes32(initCodeHash);

        bytes32 salt = bytes32(uint256(0x9563));

        admin = computeCreate2Address(salt, initCodeHash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: salt}(owner);
            require(admin == address(deployed), "admin mismatched address");

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            require(Admin(payable(admin)).owner() == owner, "admin mismatched owner");
            console.log("admin already deployed");
        }
    }
}
