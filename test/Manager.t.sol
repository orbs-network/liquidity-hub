// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "./Workbench.sol";

import "src/Manager.sol";

contract ManagerTest is BaseTest {
    Manager public manager;
    address public owner;

    function setUp() public virtual override withMockConfig {
        super.setUp();
        owner = makeAddr("owner");
        manager = new Manager(IWETH(config.weth), owner);
    }

    function testOwned() public {
        assertEq(manager.owner(), owner);
        assertEq(manager.allowed(owner), true);
        assertEq(manager.allowed(address(0)), false);
        assertEq(manager.allowed(address(1)), false);
    }

    function testAllowed() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        hoax(owner);
        manager.set(addresses, true);
        assertEq(manager.allowed(address(1)), true);
    }
}
