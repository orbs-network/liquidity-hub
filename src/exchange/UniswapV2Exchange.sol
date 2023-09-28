// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExchange} from "./IExchange.sol";

/**
 * LiquidityHub IUniswapV2Router02 Exchange
 */
contract UniswapV2Exchange is IExchange {
    using SafeERC20 for IERC20;

    error InvalidPath(address[] path);

    /**
     * @dev data: address[] path
     * @dev does not validate amountOutMin
     */
    function delegateSwap(Swap calldata s) external override {
        address[] memory path = abi.decode(s.data, (address[]));
        if (path.length < 2 || path[0] != s.token) revert InvalidPath(path);
        IERC20(s.token).safeIncreaseAllowance(s.to, s.amount);
        IUniswapV2Router02(s.to).swapExactTokensForTokens(s.amount, 1, path, address(this), block.timestamp);
    }
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}
