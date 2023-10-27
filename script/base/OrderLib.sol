// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {ExclusiveDutchOrder, DutchInput} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";

import {Config} from "script/base/Base.sol";

import {LiquidityHub, IMulticall, IReactor, IERC20, SignedOrder} from "src/LiquidityHub.sol";
import {Treasury, IWETH} from "src/Treasury.sol";

struct RFQ {
    address swapper;
    address inToken;
    address outToken;
    uint256 inAmount;
    uint256 outAmount;
}

struct Order {
    bytes abiEncoded;
    ExclusiveDutchOrder order;
}

library OrderLib {
    function createOrder(Config memory config, RFQ memory rfq) public view returns (Order memory result) {
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = rfq.swapper;
            order.info.nonce = block.timestamp;
            order.info.deadline = block.timestamp + 10 minutes;
            order.decayStartTime = order.info.deadline;
            order.decayEndTime = order.info.deadline;

            order.input.token = ERC20(rfq.inToken);
            order.input.startAmount = rfq.inAmount;
            order.input.endAmount = rfq.inAmount;

            order.outputs = OutputsBuilder.singleDutch(rfq.outToken, rfq.outAmount, rfq.outAmount, rfq.swapper);
        }
        result.order = order;
        result.abiEncoded = abi.encode(order);
    }
}
