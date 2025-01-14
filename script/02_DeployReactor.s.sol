// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";

import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

contract DeployReactor is BaseScript {
    function run() public returns (address reactor) {
        bytes32 salt = vm.envOr("SALT", bytes32(uint256(0)));

        bytes32 initCodeHash =
            hashInitCode(type(ExclusiveDutchOrderReactor).creationCode, abi.encode(Consts.PERMIT2_ADDRESS, address(0)));
        console.logBytes32(initCodeHash);

        reactor = computeCreate2Address(salt, initCodeHash);

        if (reactor.code.length == 0) {
            vm.broadcast();
            ExclusiveDutchOrderReactor deployed =
                new ExclusiveDutchOrderReactor{salt: salt}(IPermit2(Consts.PERMIT2_ADDRESS), address(0));
            require(reactor == address(deployed), "reactor mismatched address");
        } else {
            console.log("reactor already deployed");
        }
    }
}
