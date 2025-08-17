// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

/**
 * SwapExecutor
 */
contract SwapExecutor is IReactorCallback, IValidationCallback {
    using SafeERC20 for IERC20;

    error InvalidSender(address sender);
    error InvalidOrder();

    event Resolved(
        bytes32 indexed orderHash,
        address indexed swapper,
        address indexed ref,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    );

    event ExtraOut(address indexed recipient, address token, uint256 amount);

    event Surplus(address indexed ref, address swapper, address token, uint256 amount, uint256 refshare);

    uint8 public constant VERSION = 6;
    address public constant INVALID_ADDRESS = address(1);

    address public immutable multicall;
    address public immutable reactor;
    address public immutable allowed;

    constructor(address _multicall, address _reactor, address _allowed) {
        multicall = _multicall;
        reactor = _reactor;
        allowed = _allowed;
    }

    modifier onlyAllowed() {
        if (!IAdmin(allowed).allowed(msg.sender)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    /**
     * Entry point
     */
    function execute(SignedOrder calldata order, IMulticall3.Call[] calldata calls, uint256 outAmountSwapper)
        external
        onlyAllowed
    {
        IReactor(reactor).executeWithCallback(order, abi.encode(calls, outAmountSwapper));

        ExclusiveDutchOrder memory o = abi.decode(order.order, (ExclusiveDutchOrder));
        (address ref, uint8 share) = abi.decode(o.info.additionalValidationData, (address, uint8));

        _surplus(ref, o.info.swapper, address(o.input.token), share);
        for (uint256 i = 0; i < o.outputs.length; i++) {
            _surplus(ref, o.info.swapper, address(o.outputs[i].token), share);
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
        if (outAmountSwapper > outAmount) _transfer(outToken, order.info.swapper, outAmountSwapper - outAmount);

        address ref = abi.decode(order.info.additionalValidationData, (address));

        emit Resolved(
            order.hash, order.info.swapper, ref, address(order.input.token), outToken, order.input.amount, outAmount
        );
    }

    function _executeMulticall(IMulticall3.Call[] memory calls) private {
        Address.functionDelegateCall(multicall, abi.encodeWithSelector(IMulticall3.aggregate.selector, calls));
    }

    function _handleOrderOutputs(ResolvedOrder memory order) private returns (address outToken, uint256 outAmount) {
        outToken = INVALID_ADDRESS;
        for (uint256 i = 0; i < order.outputs.length; i++) {
            uint256 amount = order.outputs[i].amount;

            if (amount > 0) {
                address token = address(order.outputs[i].token);
                _outputReactor(token, amount);

                if (order.outputs[i].recipient == order.info.swapper) {
                    if (outToken != INVALID_ADDRESS && outToken != token) revert InvalidOrder();
                    outToken = token;
                    outAmount += amount;
                } else {
                    emit ExtraOut(order.outputs[i].recipient, token, amount);
                }
            }
        }
    }

    function _surplus(address ref, address swapper, address token, uint8 share) private {
        uint256 balance = _balanceOf(token, address(this));
        if (balance == 0) return;

        uint256 refshare = (ref != address(0)) ? balance * share / 100 : 0;

        if (refshare > 0) _transfer(token, ref, refshare);
        _transfer(token, swapper, balance - refshare);

        emit Surplus(ref, swapper, token, balance, refshare);
    }

    function _outputReactor(address token, uint256 amount) private {
        if (token == address(0)) {
            Address.sendValue(payable(address(reactor)), amount);
        } else {
            uint256 allowance = IERC20(token).allowance(address(this), address(reactor));
            IERC20(token).safeApprove(address(reactor), 0);
            IERC20(token).safeApprove(address(reactor), allowance + amount);
        }
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
        if (filler != address(this)) revert InvalidSender(filler);
    }

    receive() external payable {
        // accept ETH
    }
}

interface IAdmin {
    function allowed(address) external view returns (bool);
}
