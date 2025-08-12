// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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

contract OrderReactor is BaseReactor {
    using Math for uint256;

    uint256 public constant COSIGNATURE_FRESHNESS = 1 minutes;
    uint256 public constant BPS = 10_000;

    address public immutable cosigner;

    error InvalidOrder();
    error InvalidCosignature();
    error StaleCosignature();
    error CosignedMaxAmount();

    constructor(address _repermit, address _cosigner) BaseReactor(IPermit2(_repermit), address(0)) {
        cosigner = _cosigner;
    }

    function _resolve(SignedOrder calldata signedOrder)
        internal
        view
        override
        returns (ResolvedOrder memory resolvedOrder)
    {
        OrderLib.CosignedOrder memory cosigned = abi.decode(signedOrder.order, (OrderLib.CosignedOrder));

        _validate(cosigned);
        _validateCosignature(cosigned);
        uint256 outAmount = _resolveOutAmount(cosigned);
        resolvedOrder = _resolveStruct(cosigned, outAmount);

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

    function _validate(OrderLib.CosignedOrder memory cosigned) private pure {
        if (cosigned.order.input.amount == 0) revert InvalidOrder();
        if (cosigned.order.input.amount > cosigned.order.input.maxAmount) revert InvalidOrder();
        if (cosigned.order.output.amount > cosigned.order.output.maxAmount) revert InvalidOrder();
        if (cosigned.order.input.token == address(0)) revert InvalidOrder();
        if (cosigned.order.slippage >= BPS) revert InvalidOrder();
        if (cosigned.cosignatureData.input.value == 0) revert InvalidOrder();
        if (cosigned.cosignatureData.output.value == 0) revert InvalidOrder();
    }

    function _validateCosignature(OrderLib.CosignedOrder memory cosigned) private view {
        if (cosigned.cosignatureData.timestamp + COSIGNATURE_FRESHNESS < block.timestamp) revert StaleCosignature();

        bytes32 digest = RePermit(address(permit2)).hashTypedData(OrderLib.hash(cosigned.cosignatureData));
        if (!SignatureChecker.isValidSignatureNow(cosigner, digest, cosigned.cosignature)) revert InvalidCosignature();
    }

    function _resolveOutAmount(OrderLib.CosignedOrder memory cosigned) private pure returns (uint256 outAmount) {
        uint256 cosignedOutput = cosigned.order.input.amount.mulDiv(
            cosigned.cosignatureData.output.value, cosigned.cosignatureData.input.value
        );
        if (cosignedOutput > cosigned.order.output.maxAmount) revert CosignedMaxAmount();

        uint256 minOut = cosignedOutput.mulDiv(BPS - cosigned.order.slippage, BPS);
        outAmount = minOut.max(cosigned.order.output.amount);
    }

    function _resolveStruct(OrderLib.CosignedOrder memory cosigned, uint256 outAmount)
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
        resolvedOrder.hash = OrderLib.hash(cosigned.order);
    }
}
