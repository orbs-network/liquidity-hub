// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {RePermit} from "src/RePermit.sol";
import {Base, Consts} from "script/base/Base.sol";

contract DeployRepermit is Base {

    function run() public returns (address reactor) {
        reactor = computeCreate2Address(
            0,
            hashInitCode(type(RePermit).creationCode, address(0))
        );

        if (reactor.code.length == 0) {
            vm.broadcast(deployer);
            require(
                reactor
                    == address(new RePermit{salt: 0}())
            );
        } else {
            console.log("already deployed");
        }
    }
}

