// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base} from "script/base/Base.sol";

contract UpdateWhitelist is Base {
    uint256 public constant BATCH_SIZE = 300;

    function run() public {
        address[] memory list = _readList();
        for (uint256 i = 0; i < list.length; i += BATCH_SIZE) {
            uint256 size = i + BATCH_SIZE < list.length ? BATCH_SIZE : list.length - i;
            address[] memory batch = new address[](size);
            for (uint256 j = 0; j < size; j++) {
                batch[j] = list[i + j];
            }
            vm.broadcast(deployer);
            config.treasury.set(batch, true);
        }
    }

    function _readList() private view returns (address[] memory) {
        string memory path = string.concat(vm.projectRoot(), "/script/input/", "whitelist.json");
        return abi.decode(vm.parseJson(vm.readFile(path)), (address[]));
    }
}
