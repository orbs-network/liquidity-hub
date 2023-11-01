// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base, Config, Order, RFQ} from "script/base/Base.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract CreateExecution is Base {
    function run() public returns (address to, bytes memory data) {
        SignedOrder[] memory orders = new SignedOrder[](0);
        Call[] memory calls = new Call[](0);

        to = address(config.executor);
        data = abi.encodeWithSelector(config.executor.execute.selector, orders, calls);
    }
}
