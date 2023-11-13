// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Base, Config, Order, RFQ} from "script/base/Base.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";

contract CreateOrder is Base {
    function run() public returns (bytes memory encoded, bytes32 hash, string memory permitData) {
        RFQ memory rfq = RFQ({
            swapper: vm.envAddress("LH_SWAPPER"),
            inToken: vm.envAddress("LH_INTOKEN"),
            outToken: vm.envAddress("LH_OUTTOKEN"),
            inAmount: vm.envUint("LH_INAMOUNT"),
            outAmount: vm.envUint("LH_OUTAMOUNT")
        });

        Order memory o = createOrder(rfq);
        encoded = o.encoded;
        hash = o.hash;
        permitData = o.permitData;
    }
}
