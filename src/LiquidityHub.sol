// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

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

    // event Order();
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
    function execute(SignedOrder[] calldata orders, Call[] calldata calls) external onlyAllowed {
        reactor.executeBatchWithCallback(orders, abi.encode(calls));
        _excess(orders);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        _executeMulticall(abi.decode(callbackData, (Call[])));
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

    function _excess(SignedOrder[] calldata orders) private {
        for (uint256 i = 0; i < orders.length;) {
            ExclusiveDutchOrder memory order = abi.decode(orders[i].order, (ExclusiveDutchOrder));
            
            address ref = abi.decode(order.info.additionalValidationData, (address));

            _withdraw(address(order.input.token), ref);
            _withdraw(address(order.outputs[0].token), ref);

            unchecked {++i;}
        }
    }

    function withdraw(address token, address ref) public onlyAllowed {
        uint16 bps = admin.shares(ref);

        if (token == address(0)) {
            uint256 balance = address(this).balance;
            if (balance == 0) return;

            uint256 share = (balance * bps) / admin.BPS;
            Address.sendValue(payable(ref), share);
            Address.sendValue(payable(admin), balance - share);
            
            emit Excess(ref, token, share);
            emit Excess(address(admin), token, balance - share);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance == 0) return;

            uint256 share = (balance * bps) / admin.BPS;
            IERC20(token).safeTransfer(ref, share);
            IERC20(token).safeTransfer(address(admin), balance - share);
            
            emit Excess(ref, token, share);
            emit Excess(address(admin), token, balance - share);
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
