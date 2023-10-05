// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";

import "src/Treasury.sol";

contract TreasuryTest is BaseTest {
    Treasury public treasury;
    address public owner;

    function setUp() public virtual override withMockConfig {
        super.setUp();
        owner = makeAddr("owner");
        treasury = new Treasury(IWETH(config.weth), owner);
    }

    function testOwned() public {
        assertEq(treasury.owner(), owner);
        assertEq(treasury.allowed(owner), true);
        assertEq(treasury.allowed(address(0)), false);
        assertEq(treasury.allowed(address(1)), false);
    }

    function testAllowed() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        hoax(owner);
        treasury.setAllowed(addresses, true);
        assertEq(treasury.allowed(address(1)), true);
    }

    function testGetAllowed() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        hoax(owner);
        treasury.setAllowed(addresses, true);

        assertEq(treasury.getAllowed(addresses)[0], true);
    }
}
