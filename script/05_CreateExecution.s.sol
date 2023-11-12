// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base, Config, Order, RFQ} from "script/base/Base.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract CreateExecution is Base {
    function run() public view returns (address to, bytes memory data) {
        bytes[] memory iorders = vm.envBytes("LH_ORDERS", ",");
        bytes[] memory isigs = vm.envBytes("LH_SIGS", ",");
        if (iorders.length != isigs.length) revert("invalid length");

        SignedOrder[] memory orders = new SignedOrder[](iorders.length);

        Call[] memory calls = abi.decode(vm.envBytes("LH_CALLS"), (Call[]));
        for (uint256 i = 0; i < iorders.length; i++) {
            orders[i] = SignedOrder({order: iorders[i], sig: isigs[i]});
        }

        to = address(config.executor);
        data = abi.encodeWithSelector(config.executor.execute.selector, orders, calls);
    }
}
