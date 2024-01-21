// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";
import {Base, Consts} from "script/base/Base.sol";

contract DeployPartialOrderReactor is Base {
    function run() public returns (address reactor) {
        reactor =
            computeCreate2Address(0, hashInitCode(type(PartialOrderReactor).creationCode, abi.encode(config.repermit)));

        if (reactor.code.length == 0) {
            vm.broadcast(deployer);
            require(reactor == address(new PartialOrderReactor{salt: 0}(config.repermit)));
        } else {
            console.log("already deployed");
        }
    }
}
