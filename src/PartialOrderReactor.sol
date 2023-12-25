// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder, InputToken, ERC20, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";
import {OrderInfoLib, OrderInfo} from "uniswapx/src/lib/OrderInfoLib.sol";
import {BaseReactor, IPermit2} from "uniswapx/src/reactors/BaseReactor.sol";
import {ExclusivityOverrideLib} from "uniswapx/src/lib/ExclusivityOverrideLib.sol";

import {Consts} from "./Consts.sol";
import {IMulticall, Call} from "./IMulticall.sol";
import {RePermit, RePermitLib} from "./RePermit.sol";

import {PartialOrderLib} from "./PartialOrderLib.sol";

contract PartialOrderReactor is BaseReactor {
    using SafeERC20 for IERC20;

    RePermit public immutable repermit;

    constructor(RePermit _repermit) BaseReactor(IPermit2(Consts.PERMIT2_ADDRESS), address(0)) {
        repermit = _repermit;
    }

    function resolve(SignedOrder calldata signedOrder)
        internal
        view
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        PartialOrderLib.PartialOrder memory order = abi.decode(signedOrder.order, (PartialOrderLib.PartialOrder));
        // _validateOrder(order); // :amounts

        resolvedOrder.info = order.info;
        resolvedOrder.input =
            InputToken({token: ERC20(order.input.token), amount: order.input.amount, maxAmount: order.input.amount});
        resolvedOrder.sig = signedOrder.sig;
        resolvedOrder.hash = PartialOrderLib.hash(order);

        OutputToken[] memory outputs;
        PartialOrderLib.PartialOutput[] memory partialOutputs = order.outputs;
        assembly {
            outputs := partialOutputs
        }
        resolvedOrder.outputs = outputs;

        ExclusivityOverrideLib.handleOverride(
            resolvedOrder, order.exclusiveFiller, order.info.deadline, order.exclusivityOverrideBps
        );
    }

    function transferInputTokens(ResolvedOrder memory order, address to) internal override {
        repermit.repermitWitnessTransferFrom(
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(address(order.input.token), order.input.amount),
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
