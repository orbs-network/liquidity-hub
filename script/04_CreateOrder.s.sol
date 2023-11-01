// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base, Config, Order, RFQ} from "script/base/Base.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract CreateOrder is Base {
    function run() public returns (Order memory) {
        RFQ memory rfq = abi.decode(vm.envBytes("LH_RFQ"), (RFQ));
        return createOrder(rfq);
    }
}
