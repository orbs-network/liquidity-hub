// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";
import {Base, Consts} from "script/base/Base.sol";

contract DeployPartialOrderReactor is Base {

    function run() public returns (address reactor) {
        RePermit rePermit = RePermit(config.repermit);
        reactor = computeCreate2Address(
            0,
            hashInitCode(type(PartialOrderReactor).creationCode, address(rePermit))
        );

        if (reactor.code.length == 0) {
            vm.broadcast(deployer);
            require(
                reactor
                    == address(new PartialOrderReactor{salt: 0}(address(rePermit)))
            );
        } else {
            console.log("already deployed");
        }
    }
}