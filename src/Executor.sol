// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

/**
 * LiquidityHub Executor
 */
contract Executor is IReactorCallback, IValidationCallback {
    error InvalidSender(address sender);

    address public immutable multicall;
    IReactor public immutable reactor;

    constructor(address _multicall, IReactor _reactor) {
        multicall = _multicall;
        reactor = _reactor;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    function execute(SignedOrder calldata order, bytes calldata callbackData) external {
        reactor.executeWithCallback(order, callbackData);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        ResolvedOrder memory order = orders[0];

        (IMulticall3.Call[] memory calls) = abi.decode(callbackData, (IMulticall3.Call[]));

        _executeMulticall(calls);

        _handleOrderOutputs(order);
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(multicall, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls));
    }

    function _handleOrderOutputs(ResolvedOrder memory order) private {
        for (uint256 i = 0; i < order.outputs.length; i++) {
            uint256 amount = order.outputs[i].amount;

            if (amount > 0) {
                address token = address(order.outputs[i].token);
                _outputReactor(token, amount);
            }
        }
    }

    function _outputReactor(address token, uint256 amount) private {
        if (token == address(0)) {
            Address.sendValue(payable(address(reactor)), amount);
        } else {
            uint256 allowance = IERC20(token).allowance(address(this), address(reactor));
            SafeERC20.safeApprove(IERC20(token), address(reactor), 0);
            SafeERC20.safeApprove(IERC20(token), address(reactor), allowance + amount);
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
