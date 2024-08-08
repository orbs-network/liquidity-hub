// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {OrderLib} from "./OrderLib.sol";
import {Permit2Lib} from "./Permit2Lib.sol";

library OracleOrderLib {
    struct OracleOrder {
        OrderLib.OrderInfo info;
        Input input;
        Output[] outputs;
    }

    struct Input {
        address token;
        uint256 amount;
    }

    struct Output {
        address token;
        uint256 amount;
        address recipient;
    }

    string internal constant INPUT_TYPE = "Input(address token,uint256 amount)";
    bytes32 internal constant INPUT_TYPE_HASH = keccak256(bytes(INPUT_TYPE));

    string internal constant OUTPUT_TYPE = "Output(address token,uint256 amount,address recipient)";
    bytes32 internal constant OUTPUT_TYPE_HASH = keccak256(bytes(OUTPUT_TYPE));

    string internal constant ORACLE_ORDER_TYPE = "OracleOrder(OrderInfo info,Input input,Output[] outputs)";
    bytes32 internal constant ORACLE_ORDER_TYPE_HASH =
        keccak256(abi.encodePacked(ORACLE_ORDER_TYPE, INPUT_TYPE, OrderLib.ORDER_INFO_TYPE, OUTPUT_TYPE));

    string internal constant WITNESS_TYPE = string(
        abi.encodePacked(
            "OracleOrder witness)",
            INPUT_TYPE,
            ORACLE_ORDER_TYPE,
            OrderLib.ORDER_INFO_TYPE,
            OUTPUT_TYPE,
            Permit2Lib.TOKEN_PERMISSIONS_TYPE
        )
    );

    function hash(OracleOrder memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORACLE_ORDER_TYPE_HASH,
                OrderLib.hash(order.info),
                keccak256(abi.encode(INPUT_TYPE_HASH, order.input)),
                hash(order.outputs)
            )
        );
    }

    function hash(Output[] memory outputs) internal pure returns (bytes32) {
        bytes memory packedHashes = new bytes(32 * outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            bytes32 outputHash = keccak256(abi.encode(OUTPUT_TYPE_HASH, outputs[i]));
            assembly {
                mstore(add(add(packedHashes, 0x20), mul(i, 0x20)), outputHash)
            }
        }
        return keccak256(packedHashes);
    }
}
