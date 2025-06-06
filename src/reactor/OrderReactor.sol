// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

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
    error InvalidCosignature();

    constructor(address _repermit) BaseReactor(IPermit2(_repermit), address(0)) {}

    function _resolve(SignedOrder calldata signedOrder)
        internal
        view
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        OrderLib.Order memory order = abi.decode(signedOrder.order, (OrderLib.Order));

        // hash the order _before_ overriding amounts, as this is the hash the user would have signed
        bytes32 orderHash = OrderLib.hash(order);

        _validateCosignature(orderHash, order);
        // _updateWithCosignerAmounts(order);

        resolvedOrder.input = InputToken(ERC20(order.input.token), order.input.amount, order.input.maxAmount);
        resolvedOrder.outputs = new OutputToken[](1);
        resolvedOrder.outputs[0] = OutputToken(order.output.token, order.output.amount, order.output.recipient);
        resolvedOrder.sig = signedOrder.sig;
        resolvedOrder.hash = orderHash;

        ExclusivityLib.handleExclusiveOverride(
            resolvedOrder, order.exclusiveFiller, order.info.deadline, order.exclusivityOverrideBps
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
            OrderLib.WITNESS_TYPE,
            order.sig
        );
    }

    function _validateCosignature(bytes32 orderHash, OrderLib.Order memory order) internal pure {
        // cosigner signs over (orderHash || cosignerData)
        // bytes32 hash = keccak256(abi.encodePacked(orderHash, abi.encode(order.cosignerData)));
        // if (!SignatureChecker.isValidSignatureNow(order.cosigner, hash, order.cosignature)) revert InvalidCosignature();
    }
}
