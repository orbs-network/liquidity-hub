// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {OrderInfoLib, OrderInfo} from "uniswapx/src/lib/OrderInfoLib.sol";
import {RePermit, RePermitLib} from "./RePermit.sol";

library PartialOrderLib {
    struct PartialOrder {
        OrderInfo info;
        address exclusiveFiller;
        uint256 exclusivityOverrideBps;
        PartialInput input;
        PartialOutput[] outputs;
    }

    struct PartialInput {
        address token;
        uint256 amount;
    }

    struct PartialOutput {
        address token;
        uint256 amount;
        address recipient;
    }

    string internal constant PARTIAL_INPUT_TYPE = "PartialInput(address token,uint256 amount)";
    bytes32 internal constant PARTIAL_INPUT_TYPE_HASH = keccak256(bytes(PARTIAL_INPUT_TYPE));

    string internal constant PARTIAL_OUTPUT_TYPE = "PartialOutput(address token,uint256 amount,address recipient)";
    bytes32 internal constant PARTIAL_OUTPUT_TYPE_HASH = keccak256(bytes(PARTIAL_OUTPUT_TYPE));

    string internal constant PARTIAL_ORDER_TYPE =
        "PartialOrder(OrderInfo info,address exclusiveFiller,uint256 exclusivityOverrideBps,PartialInput input,PartialOutput[] outputs)";

    bytes32 internal constant PARTIAL_ORDER_TYPE_HASH = keccak256(
        abi.encodePacked(PARTIAL_ORDER_TYPE, OrderInfoLib.ORDER_INFO_TYPE, PARTIAL_INPUT_TYPE, PARTIAL_OUTPUT_TYPE)
    );

    string internal constant WITNESS_TYPE = string(
        abi.encodePacked(
            "PartialOrder witness)",
            OrderInfoLib.ORDER_INFO_TYPE,
            PARTIAL_INPUT_TYPE,
            PARTIAL_ORDER_TYPE,
            PARTIAL_OUTPUT_TYPE,
            RePermitLib.TOKEN_PERMISSIONS_TYPE
        )
    );

    function hash(PartialOrder memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                PARTIAL_ORDER_TYPE_HASH,
                OrderInfoLib.hash(order.info),
                order.exclusiveFiller,
                order.exclusivityOverrideBps,
                keccak256(abi.encode(PARTIAL_INPUT_TYPE_HASH, order.input)),
                hash(order.outputs)
            )
        );
    }

    function hash(PartialOutput[] memory outputs) internal pure returns (bytes32) {
        unchecked {
            bytes memory packedHashes = new bytes(32 * outputs.length);
            for (uint256 i = 0; i < outputs.length; i++) {
                bytes32 outputHash = keccak256(abi.encode(PARTIAL_OUTPUT_TYPE_HASH, outputs[i]));
                assembly {
                    mstore(add(add(packedHashes, 0x20), mul(i, 0x20)), outputHash)
                }
            }
            return keccak256(packedHashes);
        }
    }
}
