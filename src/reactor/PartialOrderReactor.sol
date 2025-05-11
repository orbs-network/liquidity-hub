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
import {PartialOrderLib} from "src/reactor/PartialOrderLib.sol";

contract PartialOrderReactor is BaseReactor {
    RePermit public immutable repermit;

    error InvalidOrder();

    constructor(RePermit _repermit) BaseReactor(IPermit2(address(0)), address(0)) {
        repermit = _repermit;
    }

    function _resolve(SignedOrder calldata signedOrder)
        internal
        view
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        PartialOrderLib.PartialFill memory fill = abi.decode(signedOrder.order, (PartialOrderLib.PartialFill));
        PartialOrderLib.PartialOrder memory order = fill.order;

        if (order.outputs.length != 1) revert InvalidOrder();

        resolvedOrder.info.reactor = IReactor(order.info.reactor);
        resolvedOrder.info.swapper = order.info.swapper;
        resolvedOrder.info.nonce = order.info.nonce;
        resolvedOrder.info.deadline = order.info.deadline;
        resolvedOrder.info.additionalValidationContract = IValidationCallback(order.info.additionalValidationContract);
        resolvedOrder.info.additionalValidationData = order.info.additionalValidationData;
        resolvedOrder.input = InputToken({
            token: ERC20(order.input.token),
            amount: (order.input.amount * fill.outAmount) / order.outputs[0].amount,
            maxAmount: order.input.amount
        });
        resolvedOrder.sig = signedOrder.sig;
        resolvedOrder.hash = PartialOrderLib.hash(order);

        resolvedOrder.outputs = new OutputToken[](1);
        resolvedOrder.outputs[0] =
            OutputToken({token: order.outputs[0].token, amount: fill.outAmount, recipient: order.outputs[0].recipient});

        ExclusivityLib.handleExclusiveOverride(
            resolvedOrder, order.exclusiveFiller, order.info.deadline, order.exclusivityOverrideBps
        );
    }

    function _transferInputTokens(ResolvedOrder memory order, address to) internal override {
        repermit.repermitWitnessTransferFrom(
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(address(order.input.token), order.input.maxAmount),
                order.info.nonce,
                order.info.deadline
            ),
            RePermitLib.TransferRequest(to, order.input.amount),
            order.info.swapper,
            order.hash,
            PartialOrderLib.WITNESS_TYPE,
            order.sig
        );
    }
}
