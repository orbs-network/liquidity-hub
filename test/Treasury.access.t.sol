// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/BaseTest.sol";

import {Treasury} from "src/Treasury.sol";

contract TreasuryAccessTest is BaseTest {
    function setUp() public withMockConfig {}

    function test_Owned() public {
        assertNotEq(config.treasury.owner(), address(0));
    }

    function test_Allowed() public {
        assertEq(config.treasury.allowed(config.treasury.owner()), true);
        assertEq(config.treasury.allowed(address(0)), false);
        assertEq(config.treasury.allowed(address(1)), false);
    }

    function test_Allow_OnlyOwner() public {
        hoax(config.treasury.owner());
        config.treasury.allow(address(1));
        assertEq(config.treasury.allowed(address(1)), true);
    }

    function test_Revert_Allow_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        config.treasury.allow(address(1));
    }

    function test_Withdraw_OnlyAllowed() public {
        hoax(config.treasury.owner());
        config.treasury.withdraw();
    }

    function test_Revert_Withdraw_OnlyAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(Treasury.NotAllowed.selector, address(this)));
        config.treasury.withdraw();
    }
}
