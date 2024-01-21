// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PartialOrderReactor} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";

struct PartialOrderReactorDeployment {
    PartialOrderReactor reactor;
    RePermit permit;
}

contract DeployPartialOrderReactor is Script {

    function setUp() public {}

    function run() public returns (PartialOrderReactorDeployment memory deployment) {
        RePermit rePermit = RePermit(vm.envAddress("FOUNDRY_REPERMIT"));
        vm.startBroadcast();

        PartialOrderReactor reactor = new PartialOrderReactor(rePermit);
        console2.log("PartialOrderReactor", address(reactor));

        vm.stopBroadcast();

        return PartialOrderReactorDeployment(reactor, rePermit);
    }
}