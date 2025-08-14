// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {
    IReactor,
    IValidationCallback,
    ResolvedOrder,
    SignedOrder,
    InputToken,
    ERC20,
    OutputToken,
    OrderInfo
} from "uniswapx/src/base/ReactorStructs.sol";
import {BaseReactor, IPermit2} from "uniswapx/src/reactors/BaseReactor.sol";
import {ExclusivityLib} from "uniswapx/src/lib/ExclusivityLib.sol";

import {RePermit, RePermitLib} from "src/repermit/RePermit.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {OrderValidationLib} from "src/reactor/OrderValidationLib.sol";
import {CosignatureValidationLib} from "src/reactor/CosignatureValidationLib.sol";
import {ResolutionLib} from "src/reactor/ResolutionLib.sol";
import {EpochLib} from "src/reactor/EpochLib.sol";

contract OrderReactor is BaseReactor {
    using Math for uint256;

    address public immutable cosigner;

    // order hash => next epoch
    mapping(bytes32 => uint256) public epochs;

    constructor(address _repermit, address _cosigner) BaseReactor(IPermit2(_repermit), address(0)) {
        cosigner = _cosigner;
    }

    function _resolve(SignedOrder calldata signedOrder)
        internal
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        OrderLib.CosignedOrder memory cosigned = abi.decode(signedOrder.order, (OrderLib.CosignedOrder));
        bytes32 orderHash = OrderLib.hash(cosigned.order);

        OrderValidationLib.validateOrder(cosigned.order);
        CosignatureValidationLib.validateCosignature(cosigned, orderHash, cosigner, address(permit2));

        EpochLib.validateAndUpdate(epochs, orderHash, cosigned.order.epoch);

        uint256 outAmount = ResolutionLib.resolveOutAmount(cosigned);
        resolvedOrder = _resolveStruct(cosigned, outAmount, orderHash);

        ExclusivityLib.handleExclusiveOverride(
            resolvedOrder,
            cosigned.order.exclusiveFiller,
            cosigned.order.info.deadline,
            cosigned.order.exclusivityOverrideBps
        );
    }

    function _transferInputTokens(ResolvedOrder memory order, address to) internal override {
        RePermit(address(permit2)).repermitWitnessTransferFrom(
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(address(order.input.token), order.input.maxAmount),
                order.info.nonce,
                order.info.deadline
            ),
            RePermitLib.TransferRequest(to, order.input.amount),
            order.info.swapper,
            order.hash,
            OrderLib.WITNESS_TYPE_SUFFIX,
            order.sig
        );
    }

    function _resolveStruct(OrderLib.CosignedOrder memory cosigned, uint256 outAmount, bytes32 orderHash)
        private
        pure
        returns (ResolvedOrder memory resolvedOrder)
    {
        resolvedOrder.info = OrderInfo(
            IReactor(cosigned.order.info.reactor),
            cosigned.order.info.swapper,
            cosigned.order.info.nonce,
            cosigned.order.info.deadline,
            IValidationCallback(cosigned.order.info.additionalValidationContract),
            cosigned.order.info.additionalValidationData
        );
        resolvedOrder.input =
            InputToken(ERC20(cosigned.order.input.token), cosigned.order.input.amount, cosigned.order.input.maxAmount);
        resolvedOrder.outputs = new OutputToken[](1);
        resolvedOrder.outputs[0] = OutputToken(cosigned.order.output.token, outAmount, cosigned.order.output.recipient);
        resolvedOrder.sig = cosigned.signature;
        resolvedOrder.hash = orderHash;
    }
}
