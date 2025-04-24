// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";
import {DeltaExecutor} from "src/DeltaExecutor.sol";

contract DeployDeltaExecutor is BaseScript {
    function run() public returns (address executor) {
        address reactor = vm.envAddress("REACTOR");
        address weth = vm.envAddress("WETH");
        address[] memory allowed = new address[](2);
        allowed[0] = 0x1b6c933C4A855C9F4Ad1AFBD05EB3f51dbB83CF8;
        allowed[1] = 0x0000000000bbF5c5Fd284e657F01Bd000933C96D;

        vm.broadcast();
        return address(new DeltaExecutor(reactor, weth, allowed));
    }
}
