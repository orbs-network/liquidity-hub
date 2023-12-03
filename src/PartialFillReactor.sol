// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {BaseReactor} from "uniswapx/src/reactors/BaseReactor.sol";
import {
    ExclusiveDutchOrderReactor,
    IPermit2,
    ExclusiveDutchOrderLib
} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {Consts} from "./Consts.sol";
import {IMulticall, Call} from "./IMulticall.sol";
import {RePermit, PermitTransferFrom, TokenPermissions, SignatureTransferDetails} from "./RePermit.sol";

contract PartialFillReactor is ExclusiveDutchOrderReactor {
    using SafeERC20 for IERC20;

    RePermit public constant REPERMIT = RePermit(Consts.PERMIT2_ADDRESS);
    string public constant ORDER_TYPE =
        "ExclusiveDutchOrder witness)DutchOutput(address token,uint256 startAmount,uint256 endAmount,address recipient)ExclusiveDutchOrder(OrderInfo info,uint256 decayStartTime,uint256 decayEndTime,address exclusiveFiller,uint256 exclusivityOverrideBps,address inputToken,uint256 inputStartAmount,uint256 inputEndAmount,DutchOutput[] outputs)OrderInfo(address reactor,address swapper,uint256 nonce,uint256 deadline,address additionalValidationContract,bytes additionalValidationData)TokenPermissions(address token,uint256 amount)";

    constructor() ExclusiveDutchOrderReactor(IPermit2(Consts.PERMIT2_ADDRESS), address(0)) {}

    // function transferInputTokens(ResolvedOrder memory order, address to) internal virtual override {
    //     REPERMIT.permitWitnessTransferFrom(
    //         PermitTransferFrom(
    //             TokenPermissions(address(order.input.token), order.input.maxAmount),
    //             order.info.nonce,
    //             order.info.deadline
    //         ),
    //         SignatureTransferDetails(to, order.input.amount),
    //         order.info.swapper,
    //         order.hash,
    //         ORDER_TYPE,
    //         order.sig,
    //         order.input.amount
    //     );
    // }
}
