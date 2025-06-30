// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {OrderReactor} from "src/reactor/OrderReactor.sol";

contract DeployReactor is BaseScript {
    function run() public returns (address reactor) {
        address repermit = vm.envAddress("REPERMIT");
        address cosigner = vm.envAddress("COSIGNER");

        bytes32 hash = hashInitCode(type(OrderReactor).creationCode, abi.encode(repermit));
        console.logBytes32(hash);

        bytes32 salt = vm.envOr("SALT", bytes32(uint256(0)));
        reactor = computeCreate2Address(salt, hash);

        if (reactor.code.length == 0) {
            vm.broadcast();
            OrderReactor deployed = new OrderReactor{salt: salt}(repermit, cosigner);
            require(reactor == address(deployed), "reactor mismatched address");
        } else {
            console.log("reactor already deployed");
        }
    }
}
