// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {IProtocolFeeController} from "uniswapx/src/interfaces/IProtocolFeeController.sol";
import {ResolvedOrder, SignedOrder, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";

import {IWETH} from "./external/IWETH.sol";
import {IExchange} from "./exchange/IExchange.sol";

/**
 * LiquidityHub Executor
 */
contract LiquidityHub is IReactorCallback, IValidationCallback, IProtocolFeeController, Ownable {
    using SafeERC20 for IERC20;

    uint8 public constant VERSION = 0;

    IReactor public immutable reactor;
    IWETH public immutable weth;
    mapping(address => bool) public fillers;

    constructor(IReactor _reactor, IWETH _weth, address _owner) Ownable() {
        reactor = _reactor;
        weth = _weth;
        transferOwnership(_owner);
    }

    error InvalidSender(address sender);
    error InsufficientNativeAmount(uint256 amount);

    modifier onlyFillers() {
        if (msg.sender != owner() && !fillers[msg.sender]) revert InvalidSender(msg.sender);
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) revert InvalidSender(msg.sender);
        _;
    }

    function execute(SignedOrder calldata order, IExchange.Swap[] calldata swaps) external onlyFillers {
        reactor.executeWithCallback(order, abi.encode(swaps));
    }

    function executeBatch(SignedOrder[] calldata orders, IExchange.Swap[] calldata swaps) external onlyFillers {
        reactor.executeBatchWithCallback(orders, abi.encode(swaps));
    }

    function setFillers(address[] calldata _fillers, bool enabled) external onlyOwner {
        for (uint256 i = 0; i < _fillers.length; i++) {
            fillers[_fillers[i]] = enabled;
        }
    }

    function withdraw(IExchange.Swap[] calldata swaps, address[] calldata tokens, uint256 nativeAmountMin)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < swaps.length; i++) {
            IExchange.Swap memory s = swaps[i];
            Address.functionDelegateCall(
                address(s.exchange), abi.encodeWithSelector(IExchange.delegateSwap.selector, s)
            );
        }

        if (IERC20(address(weth)).balanceOf(address(this)) > 0) {
            weth.withdraw(IERC20(address(weth)).balanceOf(address(this)));
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(msg.sender, IERC20(tokens[i]).balanceOf(address(this)));
        }

        if (address(this).balance < nativeAmountMin) revert InsufficientNativeAmount(address(this).balance);
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    /**
     * @dev IReactorCallback
     */
    function reactorCallback(ResolvedOrder[] memory orders, bytes memory callbackData) external override onlyReactor {
        IExchange.Swap[] memory swaps = abi.decode(callbackData, (IExchange.Swap[]));
        for (uint256 i = 0; i < swaps.length; i++) {
            IExchange.Swap memory s = swaps[i];
            Address.functionDelegateCall(
                address(s.exchange), abi.encodeWithSelector(IExchange.delegateSwap.selector, s)
            );
        }

        for (uint256 i = 0; i < orders.length; i++) {
            ResolvedOrder memory order = orders[i];
            for (uint256 j = 0; j < order.outputs.length; j++) {
                IERC20(order.outputs[j].token).safeIncreaseAllowance(msg.sender, order.outputs[j].amount); // output.amount to swap recipients, enforced by reactor. anything above remains here.
            }
        }
    }

    /**
     * @dev IValidationCallback
     */
    function validate(address filler, ResolvedOrder calldata) external view override {
        if (filler != address(this)) revert InvalidSender(filler);
    }

    /**
     * @dev IProtocolFeeController
     */
    function getFeeOutputs(ResolvedOrder memory order) external pure override returns (OutputToken[] memory fees) {
        if (order.info.additionalValidationData.length == 0) return fees;
        fees = new OutputToken[](1);
        fees[0] = abi.decode(order.info.additionalValidationData, (OutputToken));
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
