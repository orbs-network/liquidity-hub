// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";

import {Treasury} from "./Treasury.sol";
import {IWETH} from "./external/IWETH.sol";
import {IExchange} from "./exchange/IExchange.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 1;

    IReactor public immutable reactor;
    Treasury public immutable treasury;

    constructor(IReactor _reactor, Treasury _treasury) {
        reactor = _reactor;
        treasury = _treasury;
    }

    error InvalidSender(address sender);

    modifier onlyAllowed() {
        if (!treasury.allowed(msg.sender)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }
    /**
     * Entry point for executing a single order
     */

    function execute(SignedOrder calldata order, IExchange.Swap[] calldata swaps) external onlyAllowed {
        reactor.executeWithCallback(order, abi.encode(swaps));
    }

    /**
     * Entry point for executing a batch of orders
     */
    function executeBatch(SignedOrder[] calldata orders, IExchange.Swap[] calldata swaps) external onlyAllowed {
        reactor.executeBatchWithCallback(orders, abi.encode(swaps));
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        IExchange.Swap[] memory swaps = abi.decode(callbackData, (IExchange.Swap[]));
        for (uint256 i = 0; i < swaps.length; i++) {
            IExchange.Swap memory s = swaps[i];
            Address.functionDelegateCall(
                address(s.exchange), abi.encodeWithSelector(IExchange.delegateSwap.selector, s)
            );
        }

        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                // if (order.outputs[j].token == address(0)) {
                // Address.sendValue(payable(msg.sender), order.outputs[j].amount); // native output
                // } else {
                IERC20(order.outputs[j].token).safeIncreaseAllowance(msg.sender, order.outputs[j].amount); // output.amount to swap recipients, enforced by reactor. anything above remains here.
                    // }
            }
        }
        // everything above including protocol fees is now enforced by reactor, only slippage left
    }

    /**
     * @dev IValidationCallback
     */
    function validate(address filler, ResolvedOrder calldata) external view override {
        if (filler != address(this)) revert InvalidSender(filler);
    }

    receive() external payable {
        // accept ETH
    }
}
