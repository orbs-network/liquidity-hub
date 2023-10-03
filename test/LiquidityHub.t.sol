// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "./Workbench.sol";

import "src/LiquidityHub.sol";

abstract contract LiquidityHubTest is BaseTest {
    using Workbench for Vm;

    address public owner;
    LiquidityHub public liquidityHub;

    function setUp() public virtual override withMockConfig {
        super.setUp();
        owner = makeAddr("owner");
        liquidityHub = new LiquidityHub(IReactor(config.reactor), IWETH(config.weth), owner);
    }

    function testOwned() public {
        assertEq(liquidityHub.owner(), owner);
    }
}
