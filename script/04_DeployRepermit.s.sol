// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {RePermit} from "src/RePermit.sol";


struct RePermitDeployment {
    RePermit repermit;
}

contract DeployRepermit is Script {

    function setUp() public {}

    function run() public returns (RePermitDeployment memory deployment) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RePermit repermit = new RePermit();
        console2.log("Repermit", address(repermit));

        vm.stopBroadcast();

        return RePermitDeployment(repermit);
    }
}