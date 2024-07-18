// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {BaseScript, Consts} from "script/base/BaseScript.sol";

contract DeployReactor is BaseScript {
    function run() public returns (address reactor) {
        reactor = computeCreate2Address(
            0,
            hashInitCode(type(ExclusiveDutchOrderReactor).creationCode, abi.encode(Consts.PERMIT2_ADDRESS, address(0)))
        );

        if (reactor.code.length == 0) {
            vm.broadcast();
            ExclusiveDutchOrderReactor deployed = new ExclusiveDutchOrderReactor{salt: 0}(IPermit2(Consts.PERMIT2_ADDRESS), address(0));
            require(reactor == address(deployed), "mismatched address");
        } else {
            console.log("already deployed");
        }
    }
}
