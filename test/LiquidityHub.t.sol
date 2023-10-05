// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";

import "src/LiquidityHub.sol";

contract LiquidityHubTest is BaseTest {
    using Workbench for Vm;

    LiquidityHub public liquidityHub;

    function setUp() public virtual override withMockConfig {
        super.setUp();
        liquidityHub = new LiquidityHub(config.reactor, config.treasury);
    }
}
