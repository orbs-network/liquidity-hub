// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

library LiquidityHubLib {
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

    event Surplus(address indexed swapper, address indexed ref, address token, uint256 amount, uint8 share);
}

interface IAllowed {
    function allowed(address) external view returns (bool);
}
