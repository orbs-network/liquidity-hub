// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

import {Consts} from "./Consts.sol";
import {Admin} from "./Admin.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 5;

    IReactor public immutable reactor;
    Admin public immutable admin;
    uint256 public constant KICKBACK = 1000;
    uint256 public constant BPS = 10_000;

    constructor(IReactor _reactor, Admin _admin) {
        reactor = _reactor;
        admin = _admin;
    }

    error InvalidSender(address sender);
    error InvalidOrder();
    error InvalidLimit(uint256 outAmount);

    event Resolved(
        bytes32 indexed orderHash,
        address indexed swapper,
        address indexed ref,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    );

    event Excess(address indexed ref, address indexed token, uint256 amount);

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
    function execute(SignedOrder calldata order, IMulticall3.Call[] calldata calls, uint256 limit)
        external
        onlyAllowed
    {
        reactor.executeWithCallback(order, abi.encode(calls, limit));
        _excess(order);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        (IMulticall3.Call[] memory calls, uint256 limit) = abi.decode(callbackData, (IMulticall3.Call[], uint256));
        _executeMulticall(calls);
        _approveReactorOutputs(orders[0], limit);
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls)
        );
    }

    function _approveReactorOutputs(ResolvedOrder memory order, uint256 limit) private {
        address outToken;
        uint256 outAmount;

        for (uint256 i = 0; i < order.outputs.length; i++) {
            uint256 amount = order.outputs[i].amount;
            if (amount == 0) continue;
            address token = address(order.outputs[i].token);

            if (token == address(0)) Address.sendValue(payable(address(reactor)), amount);
            else IERC20(token).safeIncreaseAllowance(address(reactor), amount);

            if (order.outputs[i].recipient == order.info.swapper) {
                if (outToken != address(0) && outToken != token) revert InvalidOrder();
                outToken = token;
                outAmount += amount;
            }
        }

        if (outAmount < limit) revert InvalidLimit(outAmount);

        address ref = abi.decode(order.info.additionalValidationData, (address));

        emit Resolved(
            order.hash, order.info.swapper, ref, address(order.input.token), outToken, order.input.amount, outAmount
        );
    }

    function _excess(SignedOrder calldata o) private {
        ExclusiveDutchOrder memory order = abi.decode(o.order, (ExclusiveDutchOrder));
        address ref = abi.decode(order.info.additionalValidationData, (address));

        uint256 balance = _withdraw(address(order.input.token), ref);
        emit Excess(ref, address(order.input.token), balance);

        for (uint256 i = 0; i < order.outputs.length; i++) {
            balance = _withdraw(address(order.outputs[i].token), ref);
            emit Excess(ref, address(order.outputs[i].token), balance);
        }
    }

    function _withdraw(address token, address to) private returns (uint256 balance) {
        if (token == address(0)) {
            balance = address(this).balance;
            if (balance > 0) Address.sendValue(payable(to), balance);
        } else {
            balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) IERC20(token).safeTransfer(to, balance);
        }
    }

    /**
     * @dev IValidationCallback
     */
    function validate(address filler, ResolvedOrder calldata order) external view override {
        if (filler != address(this)) revert InvalidSender(filler);
        if (order.info.additionalValidationData.length < 20) revert InvalidOrder();
    }

    receive() external payable {
        // accept ETH
    }
}
