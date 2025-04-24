// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {IWETH} from "./IWETH.sol";

/**
 * DeltaExecutor
 */
contract DeltaExecutor is IReactorCallback, IValidationCallback {
    error InvalidSender(address sender);
    error InvalidOrder();

    IReactor public immutable reactor;
    IWETH public immutable weth;
    mapping(address => bool) public allowed;

    constructor(address _reactor, address _weth, address[] memory _allowed) {
        reactor = IReactor(_reactor);
        weth = IWETH(_weth);
        for (uint256 i = 0; i < _allowed.length; ++i) {
            allowed[_allowed[i]] = true;
        }
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyAllowed() {
        if (!allowed[msg.sender]) revert InvalidSender(msg.sender);
        _;
    }

    function execute(bytes calldata signedOrder) external onlyAllowed {
        reactor.executeWithCallback(abi.decode(signedOrder, (SignedOrder)), abi.encode(msg.sender));
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory data) external override onlyReactor {
        if (orders.length != 1) revert InvalidOrder();
        ResolvedOrder memory order = orders[0];
        if (order.outputs.length != 1) revert InvalidOrder();

        _handleInput(address(order.input.token), order.info.additionalValidationData, abi.decode(data, (address)));
        _handleOutput(address(order.outputs[0].token), order.outputs[0].amount);
    }

    function _handleInput(address token, bytes memory additionalValidationData, address recipient) private {
        bool shouldUnwrap = abi.decode(additionalValidationData, (bool));
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (shouldUnwrap) {
            IWETH(address(token)).withdraw(balance);
            Address.sendValue(payable(recipient), balance);
        } else {
            IERC20(token).transfer(recipient, balance);
        }
    }

    function _handleOutput(address token, uint256 amount) private {
        if (token == address(0)) {
            Address.sendValue(payable(address(reactor)), amount);
        } else {
            SafeERC20.forceApprove(IERC20(token), address(reactor), amount);
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
