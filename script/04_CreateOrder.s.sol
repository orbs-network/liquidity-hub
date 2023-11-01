// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base, Config} from "script/base/Base.sol";
import {Orders, Order, RFQ} from "script/base/Orders.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract CreateOrder is Base, Orders {
    function run() public returns (Order memory) {
        RFQ memory rfq = RFQ({
            swapper: vm.envAddress("LH_RFQ_SWAPPER"),
            inToken: vm.envAddress("LH_RFQ_INTOKEN"),
            outToken: vm.envAddress("LH_RFQ_OUTTOKEN"),
            inAmount: vm.envUint("LH_RFQ_INAMOUNT"),
            outAmount: vm.envUint("LH_RFQ_OUTAMOUNT")
        });
        return createOrder(rfq);
    }
}
