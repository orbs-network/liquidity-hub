// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {RePermitLib} from "src/repermit/RePermit.sol";

library OrderLib {
    string internal constant ORDER_INFO_TYPE =
        "OrderInfo(address reactor,address swapper,uint256 nonce,uint256 deadline,address additionalValidationContract,bytes additionalValidationData)";
    bytes32 internal constant ORDER_INFO_TYPE_HASH = keccak256(bytes(ORDER_INFO_TYPE));

    string internal constant INPUT_TYPE = "Input(address token,uint256 amount,uint256 maxAmount)";
    bytes32 internal constant INPUT_TYPE_HASH = keccak256(bytes(INPUT_TYPE));

    string internal constant OUTPUT_TYPE = "Output(address token,uint256 amount,address recipient)";
    bytes32 internal constant OUTPUT_TYPE_HASH = keccak256(bytes(OUTPUT_TYPE));

    string internal constant ORDER_TYPE =
        "Order(OrderInfo info,uint32 epoch,address exclusiveFiller,uint256 exclusivityOverrideBps,Input input,Output output)";
    bytes32 internal constant ORDER_TYPE_HASH =
        keccak256(abi.encodePacked(ORDER_TYPE, INPUT_TYPE, ORDER_INFO_TYPE, OUTPUT_TYPE));

    string internal constant WITNESS_TYPE = string(
        abi.encodePacked(
            "Order witness)", INPUT_TYPE, ORDER_TYPE, ORDER_INFO_TYPE, OUTPUT_TYPE, RePermitLib.TOKEN_PERMISSIONS_TYPE
        )
    );

    struct OrderInfo {
        address reactor;
        address swapper;
        uint256 nonce;
        uint256 deadline;
        address additionalValidationContract;
        bytes additionalValidationData;
    }

    struct Input {
        address token;
        uint256 amount;
        uint256 maxAmount;
    }

    struct Output {
        address token;
        uint256 amount;
        address recipient;
    }

    struct Order {
        OrderInfo info;
        uint32 epoch;
        address exclusiveFiller;
        uint256 exclusivityOverrideBps;
        Input input;
        Output output;
    }

    struct Cosignature {
        uint256 outputAmount;
        uint256 timestamp;
    }

    function hash(OrderInfo memory info) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_INFO_TYPE_HASH,
                info.reactor,
                info.swapper,
                info.nonce,
                info.deadline,
                info.additionalValidationContract,
                keccak256(info.additionalValidationData)
            )
        );
    }

    function hash(Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_TYPE_HASH,
                hash(order.info),
                order.epoch,
                order.exclusiveFiller,
                order.exclusivityOverrideBps,
                keccak256(abi.encode(INPUT_TYPE_HASH, order.input)),
                keccak256(abi.encode(OUTPUT_TYPE_HASH, order.output))
            )
        );
    }

    function hashCosignature() internal pure returns (bytes32) {}
}
