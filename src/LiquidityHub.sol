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
import {IAllowed, LiquidityHubLib} from "./LiquidityHubLib.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 5;

    IReactor public immutable reactor;
    IAllowed public immutable allowed;

    constructor(IReactor _reactor, IAllowed _allowed) {
        reactor = _reactor;
        allowed = _allowed;
    }

    modifier onlyAllowed() {
        if (!allowed.allowed(msg.sender)) revert LiquidityHubLib.InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert LiquidityHubLib.InvalidSender(msg.sender);
        _;
    }

    /**
     * Entry point
     */
    function execute(SignedOrder calldata order, IMulticall3.Call[] calldata calls, uint256 outAmountSwapper)
        external
        onlyAllowed
    {
        reactor.executeWithCallback(order, abi.encode(calls, outAmountSwapper));

        ExclusiveDutchOrder memory o = abi.decode(order.order, (ExclusiveDutchOrder));
        (address ref, uint8 share) = abi.decode(o.info.additionalValidationData, (address, uint8));

        _surplus(o.info.swapper, ref, address(o.input.token), share);
        for (uint256 i = 0; i < o.outputs.length; i++) {
            _surplus(o.info.swapper, ref, address(o.outputs[i].token), share);
        }
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        ResolvedOrder memory order = orders[0];

        (IMulticall3.Call[] memory calls, uint256 outAmountSwapper) =
            abi.decode(callbackData, (IMulticall3.Call[], uint256));

        _executeMulticall(calls);
        (address outToken, uint256 outAmount) = _handleOrderOutputs(order);
        _verifyOutAmountSwapper(order.info.swapper, outToken, outAmount, outAmountSwapper);

        address ref = abi.decode(order.info.additionalValidationData, (address));

        emit LiquidityHubLib.Resolved(
            order.hash, order.info.swapper, ref, address(order.input.token), outToken, order.input.amount, outAmount
        );
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls)
        );
    }

    function _handleOrderOutputs(ResolvedOrder memory order) private returns (address outToken, uint256 outAmount) {
        for (uint256 i = 0; i < order.outputs.length; i++) {
            uint256 amount = order.outputs[i].amount;

            if (amount > 0) {
                address token = address(order.outputs[i].token);
                _approveReactor(token, amount);

                if (order.outputs[i].recipient == order.info.swapper) {
                    if (outToken != address(0) && outToken != token) revert LiquidityHubLib.InvalidOrder();
                    outToken = token;
                    outAmount += amount;
                }
            }
        }
    }

    function _verifyOutAmountSwapper(address swapper, address token, uint256 outAmount, uint256 outAmountSwapper)
        private
    {
        uint256 balance = _balanceOf(token, address(this));
        if (outAmountSwapper > balance) revert LiquidityHubLib.InvalidOutAmountSwapper(balance);
        if (outAmountSwapper > outAmount) _transfer(token, swapper, outAmountSwapper - outAmount);
    }

    function _surplus(address swapper, address ref, address token, uint8 share) private {
        uint256 balance = _balanceOf(token, address(this));
        if (balance == 0) return;

        uint256 refshare = balance * share / 100;

        if (ref != address(0) && refshare > 0) _transfer(token, ref, refshare);
        _transfer(token, swapper, _balanceOf(token, address(this)));

        emit LiquidityHubLib.Surplus(swapper, ref, token, balance, refshare);
    }

    function _approveReactor(address token, uint256 amount) private {
        if (token == address(0)) Address.sendValue(payable(address(reactor)), amount);
        else IERC20(token).safeIncreaseAllowance(address(reactor), amount);
    }

    function _transfer(address token, address to, uint256 amount) private {
        if (token == address(0)) Address.sendValue(payable(to), amount);
        else IERC20(token).safeTransfer(to, amount);
    }

    function _balanceOf(address token, address who) private view returns (uint256) {
        return (token == address(0)) ? who.balance : IERC20(token).balanceOf(who);
    }

    /**
     * @dev IValidationCallback
     */
    function validate(address filler, ResolvedOrder calldata) external view override {
        if (filler != address(this)) revert LiquidityHubLib.InvalidSender(filler);
    }

    receive() external payable {
        // accept ETH
    }
}
