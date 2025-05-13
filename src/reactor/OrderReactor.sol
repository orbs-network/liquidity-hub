// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {
    IReactor,
    IValidationCallback,
    ResolvedOrder,
    SignedOrder,
    InputToken,
    ERC20,
    OutputToken
} from "uniswapx/src/base/ReactorStructs.sol";
import {BaseReactor, IPermit2} from "uniswapx/src/reactors/BaseReactor.sol";
import {ExclusivityLib} from "uniswapx/src/lib/ExclusivityLib.sol";

import {RePermit, RePermitLib} from "src/repermit/RePermit.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";

contract OrderReactor is BaseReactor {
    error InvalidOrder();

    constructor(RePermit _repermit) BaseReactor(IPermit2(address(_repermit)), address(0)) {}

    function _resolve(SignedOrder calldata signedOrder)
        internal
        view
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        OrderLib.Order memory order = abi.decode(signedOrder.order, (OrderLib.Order));

        resolvedOrder.info.reactor = IReactor(order.info.reactor);
        resolvedOrder.info.swapper = order.info.swapper;
        resolvedOrder.info.nonce = order.info.nonce;
        resolvedOrder.info.deadline = order.info.deadline;
        resolvedOrder.info.additionalValidationContract = IValidationCallback(order.info.additionalValidationContract);
        resolvedOrder.info.additionalValidationData = order.info.additionalValidationData;
        resolvedOrder.input = InputToken(ERC20(order.input.token), order.input.amount, order.input.maxAmount);
        resolvedOrder.sig = signedOrder.sig;
        resolvedOrder.hash = OrderLib.hash(order);

        resolvedOrder.outputs = new OutputToken[](1);
        resolvedOrder.outputs[0] = OutputToken(order.output.token, order.output.amount, order.output.recipient);

        ExclusivityLib.handleExclusiveOverride(
            resolvedOrder, order.exclusiveFiller, order.info.deadline, order.exclusivityOverrideBps
        );
    }

    function _transferInputTokens(ResolvedOrder memory order, address to) internal override {
        RePermit(permit2).repermitWitnessTransferFrom(
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(address(order.input.token), order.input.maxAmount),
                order.info.nonce,
                order.info.deadline
            ),
            RePermitLib.TransferRequest(to, order.input.amount),
            order.info.swapper,
            order.hash,
            OrderLib.WITNESS_TYPE,
            order.sig
        );
    }
}
