// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

import {ExclusiveDutchOrderLib, ExclusiveDutchOrder, DutchInput} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";

import {Base, Config, Workbench} from "script/base/Base.sol";

import {LiquidityHub, Consts, IMulticall, IReactor, IERC20, SignedOrder} from "src/LiquidityHub.sol";
import {Treasury, IWETH} from "src/Treasury.sol";

struct RFQ {
    address swapper;
    address inToken;
    address outToken;
    uint256 inAmount;
    uint256 outAmount;
}

struct Order {
    ExclusiveDutchOrder order;
    bytes encoded;
    string permitData;
}

abstract contract Orders is Base {
    function createOrder(RFQ memory rfq) public returns (Order memory result) {
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
        result.encoded = abi.encode(order);

        string[] memory cmd = new string[](13);
        cmd[0] = "sed";
        cmd[1] = string.concat("-e s@<CHAINID>@", vm.toString(block.chainid), "@g");
        cmd[2] = string.concat("-e s@<PERMIT2>@", vm.toString(Consts.PERMIT2_ADDRESS), "@g");
        cmd[3] = string.concat("-e s@<SWAPPER>@", vm.toString(rfq.swapper), "@g");
        cmd[4] = string.concat("-e s@<INTOKEN>@", vm.toString(rfq.inToken), "@g");
        cmd[5] = string.concat("-e s@<INAMOUNT>@", vm.toString(rfq.inAmount), "@g");
        cmd[6] = string.concat("-e s@<OUTTOKEN>@", vm.toString(rfq.outToken), "@g");
        cmd[7] = string.concat("-e s@<OUTAMOUNT>@", vm.toString(rfq.outAmount), "@g");
        cmd[8] = string.concat("-e s@<DEADLINE>@", vm.toString(order.info.deadline), "@g");
        cmd[9] = string.concat("-e s@<NONCE>@", vm.toString(order.info.nonce), "@g");
        cmd[10] = string.concat("-e s@<REACTOR>@", vm.toString(address(order.info.reactor)), "@g");
        cmd[11] = string.concat("-e s@<EXECUTOR>@", vm.toString(address(config.executor)), "@g");
        cmd[12] = "script/input/permit.skeleton.json";

        result.permitData = string(vm.ffi(cmd));
    }
}
