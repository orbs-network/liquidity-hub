// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "./Workbench.sol";

import "src/Whitelist.sol";

contract WhitelistTest is BaseTest {
    Whitelist public whitelist;
    address public owner;

    function setUp() public virtual override {
        super.setUp();
        owner = makeAddr("owner");
        whitelist = new Whitelist(owner);
    }

    function testOwned() public {
        assertEq(whitelist.owner(), owner);
        assertEq(whitelist.allowed(owner), true);
        assertEq(whitelist.allowed(address(0)), false);
        assertEq(whitelist.allowed(address(1)), false);
    }

    function testAllowed() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        hoax(owner);
        whitelist.set(addresses, true);
        assertEq(whitelist.allowed(address(1)), true);
    }
}
