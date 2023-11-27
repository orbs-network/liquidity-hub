// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

import {Treasury} from "src/Treasury.sol";

contract DeployTreasury is Base {
    address private constant OWNER = 0xFcd300AaFE1fDB3166cd1A3B46463144fc2D46ad;

    function run() public returns (address treasury) {
        treasury = computeCreate2Address(0, hashInitCode(type(Treasury).creationCode, abi.encode(config.weth, OWNER)));

        if (treasury.code.length == 0) {
            vm.broadcast(deployer);
            require(treasury == address(new Treasury{salt: 0}(config.weth, OWNER)));
        }
    }
}
