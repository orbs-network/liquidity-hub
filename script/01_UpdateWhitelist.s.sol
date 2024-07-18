// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

contract UpdateWhitelist is BaseScript {
    uint256 public constant BATCH_SIZE = 300;

    function run() public {
        if (address(config.admin).code.length == 0) {
            console.log("admin not deployed");
            return;
        }

        address[] memory list = _readList();

        unchecked {
            for (uint256 i = 0; i < list.length; i += BATCH_SIZE) {
                uint256 size = i + BATCH_SIZE < list.length ? BATCH_SIZE : list.length - i;

                address[] memory batch = new address[](size);
                for (uint256 j = 0; j < size; j++) {
                    batch[j] = list[i + j];
                }

                vm.broadcast();
                config.treasury.set(batch, true);

                console.log("whitelist updated", i);
            }
        }

        require(config.admin.allowed(config.admin.owner()), "owner not allowed?");
        require(config.admin.allowed(list[0]), "first not allowed?");
        require(config.admin.allowed(list[list.length - 1]), "last not allowed?");
    }

    function _readList() private view returns (address[] memory) {
        string memory path = string.concat(vm.projectRoot(), "/script/input/", "whitelist.json");
        return abi.decode(vm.parseJson(vm.readFile(path)), (address[]));
    }
}
