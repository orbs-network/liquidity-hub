// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {Treasury} from "./Treasury.sol";
import {IMulticall, Call} from "./IMulticall.sol";

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
     * Entry point
     */
    function execute(SignedOrder[] calldata orders, Call[] calldata calls, address[] calldata outTokens)
        external
        onlyAllowed
    {
        reactor.executeBatchWithCallback(orders, abi.encode(calls));
        for (uint256 i = 0; i < outTokens.length; i++) {
            IERC20(outTokens[i]).safeTransfer(address(treasury), IERC20(outTokens[i]).balanceOf(address(this)));
        }
        Address.sendValue(payable(address(treasury)), address(this).balance);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        Call[] memory calls = abi.decode(callbackData, (Call[]));
        IMulticall multicall = treasury.multicall();
        if (calls.length > 0) {
            Address.functionDelegateCall(
                address(multicall), abi.encodeWithSelector(multicall.aggregate.selector, calls)
            );
        }

        // output.amount to swap recipients, enforced by reactor:
        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                if (order.outputs[j].token == address(0)) {
                    Address.sendValue(payable(msg.sender), order.outputs[j].amount);
                } else {
                    IERC20(order.outputs[j].token).safeIncreaseAllowance(msg.sender, order.outputs[j].amount);
                }
            }
        }
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
