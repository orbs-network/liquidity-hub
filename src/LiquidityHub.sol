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

    error InvalidSender(address sender);
    error InvalidOrder();
    error InvalidSwapperLimit(uint256 outAmount);

    event Resolved(
        bytes32 indexed orderHash,
        address indexed swapper,
        address indexed ref,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    );

    event Surplus(
        bytes32 indexed orderHash,
        address indexed swapper,
        address indexed ref,
        address token,
        uint256 amount,
        uint8 share
    );

    modifier onlyAllowed() {
        if (!allowed.allowed(msg.sender)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    /**
     * Entry point
     */
    function execute(SignedOrder calldata order, IMulticall3.Call[] calldata calls, uint256 swapperLimit)
        external
        onlyAllowed
    {
        reactor.executeWithCallback(order, abi.encode(calls, swapperLimit));
        _excess(order);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        ResolvedOrder memory order = orders[0];

        (IMulticall3.Call[] memory calls, uint256 swapperLimit) =
            abi.decode(callbackData, (IMulticall3.Call[], uint256));

        _executeMulticall(calls);
        (address outToken, uint256 outAmount) = _approveReactorOutputs(order);

        if (outAmount < swapperLimit) revert InvalidSwapperLimit(outAmount);

        address ref = abi.decode(order.info.additionalValidationData, (address));

        emit Resolved(
            order.hash, order.info.swapper, ref, address(order.input.token), outToken, order.input.amount, outAmount
        );
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls)
        );
    }

    function _approveReactorOutputs(ResolvedOrder memory order) private returns (address outToken, uint256 outAmount) {
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
    }

    function _excess(SignedOrder calldata o) private {
        ExclusiveDutchOrder memory order = abi.decode(o.order, (ExclusiveDutchOrder));
        (address ref, uint8 share) = abi.decode(order.info.additionalValidationData, (address, uint8));
        bytes32 orderHash = order.hash();

        _surplus(order.hash, order.info.swapper, ref, address(order.input.token), share);

        for (uint256 i = 0; i < order.outputs.length; i++) {
            _surplus(order.info.hash, order.info.swapper, ref, address(order.outputs[i].token), share);
        }
    }

    function _surplus(bytes32 orderHash, address swapper, address ref, address token, uint8 share) private {
        uint256 balance = (token == address(0)) ? address(this).balance : IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            uint256 refshare = balance * share / 100;
            (token == address(0))
                ? Address.sendValue(payable(ref), refshare)
                : IERC20(token).safeTransfer(ref, refshare);
            (token == address(0))
                ? Address.sendValue(payable(swapper), address(this).balance)
                : IERC20(token).safeTransfer(swapper, IERC20(token).balanceOf(address(this)));
            emit Surplus(orderHash, swapper, ref, token, balance, share);
        }
    }

    /**
     * @dev IValidationCallback
     */
    function validate(address filler, ResolvedOrder calldata order) external view override {
        if (filler != address(this)) revert InvalidSender(filler);
        if (order.info.additionalValidationData.length < 8) revert InvalidOrder();
    }

    receive() external payable {
        // accept ETH
    }
}

interface IAllowed {
    function allowed(address) external view returns (bool);
}
