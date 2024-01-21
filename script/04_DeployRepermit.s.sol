// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {RePermit} from "src/RePermit.sol";
import {Base, Consts} from "script/base/Base.sol";

contract DeployRePermit is Base {

    function run() public returns (address rePermit) {
        rePermit = computeCreate2Address(
            0,
            hashInitCode(type(RePermit).creationCode, address(0))
        );

        if (rePermit.code.length == 0) {
            vm.broadcast(deployer);
            require(
                rePermit
                    == address(new RePermit{salt: 0}())
            );
        } else {
            console.log("already deployed");
        }
    }
}

