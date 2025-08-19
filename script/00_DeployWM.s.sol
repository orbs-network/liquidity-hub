// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {WM} from "src/WM.sol";

contract DeployWM is BaseScript {
    function run() public returns (address wmAddr) {
        address owner = vm.envAddress("OWNER");

        bytes32 hash = hashInitCode(type(WM).creationCode, abi.encode(owner));
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(0));
        wmAddr = computeCreate2Address(salt, hash);

        if (wmAddr.code.length == 0) {
            vm.broadcast();
            WM deployed = new WM{salt: salt}(owner);
            wmAddr = address(deployed);
        } else {
            require(WM(payable(wmAddr)).owner() == owner, "wm mismatched owner");
            require(WM(payable(wmAddr)).allowed(owner), "owner not allowed");
            console.log("wm already deployed");
        }
    }
}
