// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/base/ExclusiveDutchOrder.sol";

import {Consts} from "./Consts.sol";
import {Admin} from "./Admin.sol";
import {IMulticall, Call} from "./IMulticall.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 5;

    IReactor public immutable reactor;
    Admin public immutable admin;

    constructor(IReactor _reactor, Admin _admin) {
        reactor = _reactor;
        admin = _admin;
    }

    error InvalidSender(address sender);

    modifier onlyAllowed() {
        if (!admin.allowed(msg.sender)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    /**
     * Entry point
     */
    function execute(SignedOrder[] calldata orders, Call[] calldata calls) external onlyAllowed {
        reactor.executeBatchWithCallback(orders, abi.encode(calls));

        for (uint256 i = 0; i < orders.length;) {
            ExclusiveDutchOrder memory order = abi.decode(orders[i].order, (ExclusiveDutchOrder));
            withdraw(address(order.input.token));

            for (uint256 j = 0; j < order.outputs.length;) {
                withdraw(address(order.outputs[j].token));
                unchecked {++j;}
            }

            unchecked {++i;}
        }

        uint256 nativeBalance = address(this).balance;
        if (nativeBalance > 0) Address.sendValue(payable(admin), nativeBalance);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        (Call[] memory calls) = abi.decode(callbackData, (Call[]));
        _executeMulticall(calls);
        _approveReactorOutputs(orders);
    }

    function _executeMulticall(Call[] memory calls) private {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall.aggregate.selector, calls)
        );
    }

    function _approveReactorOutputs(ResolvedOrder[] memory orders) private {
        for (uint256 i = 0; i < orders.length;) {
            ResolvedOrder memory order = orders[i];

            for (uint256 j = 0; j < order.outputs.length;) {
                uint256 amount = order.outputs[j].amount;
                if (amount == 0) continue;

                address token = order.outputs[j].token;
                if (token == address(0)) Address.sendValue(payable(address(reactor)), amount);
                else IERC20(token).safeIncreaseAllowance(address(reactor), amount);
                
                unchecked {++j;}
            }

            unchecked {++i;}
        }
    }

    function withdraw(address token) private {
        if (token == address(0)) return;
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) token.safeTransfer(admin, balance);
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
