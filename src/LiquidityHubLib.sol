// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

library LiquidityHubLib {
    error InvalidSender(address sender);
    error InvalidOrder();
    error InvalidOutAmountSwapper(uint256 balance);

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
        address indexed swapper, address indexed ref, address indexed token, uint256 amount, uint256 refshare
    );
}

interface IAllowed {
    function allowed(address) external view returns (bool);
}
