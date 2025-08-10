// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IMulticall3, ERC20Mock} from "test/base/BaseTest.sol";

import {Admin} from "src/Admin.sol";

contract AdminTest is BaseTest {
    Admin public uut;

    function setUp() public override {
        super.setUp();
        uut = Admin(payable(admin));
    }

    function test_owned() public {
        assertNotEq(uut.owner(), address(0));
        assertEq(uut.owner(), address(this));
    }

    function test_revert_owned() public {
        vm.expectRevert("Ownable: caller is not the owner");
        hoax(other);
        uut.set(new address[](0), true);
    }

    function test_allowed() public {
        assertEq(uut.allowed(uut.owner()), true);
        assertEq(uut.allowed(address(0)), false);
        assertEq(uut.allowed(other), false);

        address[] memory addrs = new address[](1);
        addrs[0] = other;
        uut.set(addrs, true);
        assertEq(uut.allowed(other), true);
    }
}
