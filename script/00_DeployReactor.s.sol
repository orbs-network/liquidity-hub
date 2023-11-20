// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {Base, Consts} from "script/base/Base.sol";

contract DeployReactor is Base {
    event DeployedReactor(address reactor);

    function run() public returns (address reactor) {
        vm.broadcast(deployer);
        reactor = address(new ExclusiveDutchOrderReactor{salt: "ORBS"}(IPermit2(Consts.PERMIT2_ADDRESS), address(0)));
        emit DeployedReactor(reactor);
    }
}