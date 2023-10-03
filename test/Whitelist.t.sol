// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "./Workbench.sol";

import "src/Whitelist.sol";

contract WhitelistTest is BaseTest {
    Whitelist public whitelist;
    address public owner;

    function setUp() public virtual override withMockConfig {
        super.setUp();
        owner = makeAddr("owner");
        whitelist = new Whitelist(owner);
    }

    function testOwned() public {
        assertEq(whitelist.owner(), owner);
    }
}
