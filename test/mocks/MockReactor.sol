// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, OrderInfo, InputToken, OutputToken, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract MockReactor is IReactor {
    function execute(SignedOrder calldata) external payable {}

    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData) external payable {
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);

        OutputToken[] memory outs = new OutputToken[](1);
        outs[0] = OutputToken({
            token: address(abi.decode(order.order, (ExclusiveDutchOrder)).outputs[0].token),
            amount: 500,
            recipient: abi.decode(order.order, (ExclusiveDutchOrder)).info.swapper
        });

        (address r, ) = abi.decode(
            abi.decode(order.order, (ExclusiveDutchOrder)).info.additionalValidationData,
            (address, uint8)
        );

        ros[0] = ResolvedOrder({
            info: OrderInfo({
                reactor: IReactor(address(this)),
                swapper: abi.decode(order.order, (ExclusiveDutchOrder)).info.swapper,
                nonce: 1,
                deadline: block.timestamp + 1 days,
                additionalValidationContract: IValidationCallback(address(0)),
                additionalValidationData: abi.encode(r)
            }),
            input: InputToken({
                token: ERC20(address(abi.decode(order.order, (ExclusiveDutchOrder)).input.token)),
                amount: 100,
                maxAmount: 100
            }),
            outputs: outs,
            sig: bytes("")
            ,
            hash: bytes32(uint256(123))
        });

        IReactorCallback(msg.sender).reactorCallback(ros, callbackData);
    }

    function executeBatch(SignedOrder[] calldata) external payable {}

    function executeBatchWithCallback(SignedOrder[] calldata, bytes calldata) external payable {}

    receive() external payable {}
}

