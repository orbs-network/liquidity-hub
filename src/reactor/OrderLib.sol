// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {RePermitLib} from "src/repermit/RePermit.sol";

library OrderLib {
    string internal constant ORDER_INFO_TYPE =
        "OrderInfo(address reactor,address swapper,uint256 nonce,uint256 deadline,address additionalValidationContract,bytes additionalValidationData)";
    bytes32 internal constant ORDER_INFO_TYPE_HASH = keccak256(bytes(ORDER_INFO_TYPE));

    string internal constant INPUT_TYPE = "Input(address token,uint256 amount,uint256 maxAmount)";
    bytes32 internal constant INPUT_TYPE_HASH = keccak256(bytes(INPUT_TYPE));

    string internal constant OUTPUT_TYPE = "Output(address token,uint256 amount,uint256 maxAmount,address recipient)";
    bytes32 internal constant OUTPUT_TYPE_HASH = keccak256(bytes(OUTPUT_TYPE));

    string internal constant ORDER_TYPE =
        "Order(OrderInfo info,address exclusiveFiller,uint256 exclusivityOverrideBps,uint32 epoch,uint32 slippage,Input input,Output output)";
    bytes32 internal constant ORDER_TYPE_HASH =
        keccak256(abi.encodePacked(ORDER_TYPE, INPUT_TYPE, ORDER_INFO_TYPE, OUTPUT_TYPE));

    string internal constant WITNESS_TYPE_SUFFIX = string(
        abi.encodePacked(
            "Order witness)", INPUT_TYPE, ORDER_TYPE, ORDER_INFO_TYPE, OUTPUT_TYPE, RePermitLib.TOKEN_PERMISSIONS_TYPE
        )
    );

    string internal constant COSIGNED_VALUE_TYPE = "CosignedValue(address token,uint256 value,uint8 decimals)";
    bytes32 internal constant COSIGNED_VALUE_TYPE_HASH = keccak256(bytes(COSIGNED_VALUE_TYPE));

    string internal constant COSIGNATURE_TYPE =
        "Cosignature(uint256 timestamp,CosignedValue input,CosignedValue output)";
    bytes32 internal constant COSIGNATURE_TYPE_HASH = keccak256(abi.encodePacked(COSIGNATURE_TYPE, COSIGNED_VALUE_TYPE));

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
        uint256 amount; // chunk
        uint256 maxAmount; // total
    }

    struct Output {
        address token;
        uint256 amount; // limit
        uint256 maxAmount; // trigger
        address recipient;
    }

    struct Order {
        OrderInfo info;
        address exclusiveFiller; // executor
        uint256 exclusivityOverrideBps;
        uint256 epoch; // seconds per chunk
        uint256 slippage; // bps
        Input input;
        Output output;
    }

    struct CosignedValue {
        address token;
        uint256 value; // in token decimals
        uint8 decimals;
    }

    struct Cosignature {
        uint256 timestamp;
        CosignedValue input;
        CosignedValue output;
    }

    struct CosignedOrder {
        Order order;
        bytes signature;
        Cosignature cosignatureData;
        bytes cosignature;
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
                order.exclusiveFiller,
                order.exclusivityOverrideBps,
                order.epoch,
                order.slippage,
                keccak256(abi.encode(INPUT_TYPE_HASH, order.input)),
                keccak256(abi.encode(OUTPUT_TYPE_HASH, order.output))
            )
        );
    }

    function hash(Cosignature memory cosignature) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                COSIGNATURE_TYPE_HASH,
                cosignature.timestamp,
                keccak256(abi.encode(COSIGNATURE_TYPE_HASH, cosignature.input)),
                keccak256(abi.encode(COSIGNATURE_TYPE_HASH, cosignature.output))
            )
        );
    }
}
