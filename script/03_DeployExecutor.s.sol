// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract DeployExecutor is Base {
    function run() public returns (address executor) {
        executor = computeCreate2Address(
            0,
            hashInitCode(
                type(LiquidityHub).creationCode, abi.encode(config.reactor, config.treasury, config.feeRecipient)
            )
        );

        if (executor.code.length == 0) {
            vm.broadcast(deployer);
            require(
                executor == address(new LiquidityHub{salt: 0}(config.reactor, config.treasury, config.feeRecipient))
            );
        } else {
            console.log("already deployed");
        }
    }
}
