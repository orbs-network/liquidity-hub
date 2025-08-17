// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library ReactorConstants {
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_SLIPPAGE = BPS / 2;
    uint256 public constant COSIGNATURE_FRESHNESS = 1 minutes;
}
