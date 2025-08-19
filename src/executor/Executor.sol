// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

/**
 * Executor
 */
contract Executor is IReactorCallback, IValidationCallback {
    address public immutable multicall;
    address public immutable reactor;
    address public immutable allowed;

    constructor(address _multicall, address _reactor, address _allowed) {
        multicall = _multicall;
        reactor = _reactor;
        allowed = _allowed;
    }

    modifier onlyAllowed() {
        if (!IWM(allowed).allowed(msg.sender)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    function execute(SignedOrder calldata order, bytes calldata callbackData) external onlyAllowed {
        IReactor(reactor).executeWithCallback(order, callbackData);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        ResolvedOrder memory order = orders[0];

        (IMulticall3.Call[] memory calls) = abi.decode(callbackData, (IMulticall3.Call[]));

        _executeMulticall(calls);

        _outputReactor(order.outputs[0].token, order.outputs[0].amount);
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(multicall, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls));
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

    error InvalidSender(address sender);
}

interface IAllowed {
    function allowed(address) external view returns (bool);
}

interface IWM {
    function allowed(address) external view returns (bool);
}
