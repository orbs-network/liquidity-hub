// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {Treasury} from "./Treasury.sol";
import {IWETH} from "./IWETH.sol";
import {IMulticall, Call} from "./IMulticall.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 1;
    IMulticall public constant MULTICALL = IMulticall(0xcA11bde05977b3631167028862bE2a173976CA11);

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

    function execute(SignedOrder calldata order, Call[] calldata calls) external onlyAllowed {
        reactor.executeWithCallback(order, abi.encode(calls));
    }

    /**
     * Entry point for executing a batch of orders
     */
    function executeBatch(SignedOrder[] calldata orders, Call[] calldata calls) external onlyAllowed {
        reactor.executeBatchWithCallback(orders, abi.encode(calls));
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        Call[] memory calls = abi.decode(callbackData, (Call[]));
        if (calls.length > 0) {
            Address.functionDelegateCall(
                address(MULTICALL), abi.encodeWithSelector(MULTICALL.aggregate3.selector, calls)
            );
        }

        uint256 count = 0;
        address[] memory tokens = new address[](orders.length * 2);
        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                if (order.outputs[j].token != address(0)) {
                    tokens[count++] = order.outputs[j].token;
                    IERC20(order.outputs[j].token).safeIncreaseAllowance(msg.sender, order.outputs[j].amount); // output.amount to swap recipients, enforced by reactor. anything above remains here.
                }
            }
        }

        for (uint256 i = 0; i < count; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            uint256 allowance = IERC20(tokens[i]).allowance(address(this), msg.sender);
            if (balance > allowance) {
                IERC20(tokens[i]).safeTransfer(address(treasury), balance - allowance);
            }
        }

        Address.sendValue(payable(msg.sender), address(this).balance);
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
