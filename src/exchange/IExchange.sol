// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

/**
 * LiquidityHub swap interface.
 * @dev implementations must assume swaps are called by delegatecall.
 */
interface IExchange {
    struct Swap {
        IExchange exchange;
        address token;
        uint256 amount;
        address to;
        bytes data;
    }

    /**
     * @dev called by Executor using delegatecall.
     */
    function delegateSwap(Swap calldata s) external;
}
