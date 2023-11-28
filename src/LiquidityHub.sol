// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {Consts} from "./Consts.sol";
import {Treasury} from "./Treasury.sol";
import {IMulticall, Call} from "./IMulticall.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 2;

    IReactor public immutable reactor;
    Treasury public immutable treasury;
    address payable public immutable feeRecipient;

    constructor(IReactor _reactor, Treasury _treasury, address payable _feeRecipient) {
        reactor = _reactor;
        treasury = _treasury;
        feeRecipient = _feeRecipient;
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
    function execute(SignedOrder[] calldata orders, Call[] calldata calls) external onlyAllowed {
        reactor.executeBatchWithCallback(orders, abi.encode(calls));
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        _executeMulticall(abi.decode(callbackData, (Call[])));
        _approveReactorOutputs(orders);
        _withdrawSlippage(orders);
    }

    function _executeMulticall(Call[] memory calls) private {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall.aggregate.selector, calls)
        );
    }

    function _approveReactorOutputs(ResolvedOrder[] memory orders) private {
        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                address token = order.outputs[j].token;
                uint256 amount = order.outputs[j].amount;
                if (token == address(0)) {
                    Address.sendValue(payable(address(reactor)), amount);
                } else {
                    IERC20(token).safeIncreaseAllowance(address(reactor), amount);
                }
            }
        }
    }

    function _withdrawSlippage(ResolvedOrder[] memory orders) private {
        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                address token = order.outputs[j].token;
                if (token != address(0)) {
                    uint256 balance = IERC20(token).balanceOf(address(this));
                    uint256 allowance = IERC20(token).allowance(address(this), address(reactor));
                    if (balance > allowance) {
                        IERC20(token).safeTransfer(feeRecipient, balance - allowance);
                    }
                }
            }
        }
        Address.sendValue(feeRecipient, address(this).balance);
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
