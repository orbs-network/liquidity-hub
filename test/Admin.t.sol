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

    function test_set_multiple_addresses() public {
        address a = makeAddr("a");
        address b = makeAddr("b");
        address c = makeAddr("c");

        address[] memory addrs = new address[](3);
        addrs[0] = a;
        addrs[1] = b;
        addrs[2] = c;

        uut.set(addrs, true);

        assertEq(uut.allowed(a), true);
        assertEq(uut.allowed(b), true);
        assertEq(uut.allowed(c), true);
    }

    function test_revoke_addresses() public {
        address a = makeAddr("a");
        address[] memory addrs = new address[](1);
        addrs[0] = a;

        // allow
        uut.set(addrs, true);
        assertEq(uut.allowed(a), true);

        // revoke
        uut.set(addrs, false);
        assertEq(uut.allowed(a), false);
    }

    function test_set_noop_on_empty_array() public {
        // Should not revert and should change nothing
        address[] memory none = new address[](0);
        uut.set(none, true);
        assertEq(uut.allowed(uut.owner()), true);
    }

    function test_transferOwnership_two_step_flow() public {
        address pending = makeAddr("pendingOwner");

        // Start transfer
        uut.transferOwnership(pending);
        assertEq(uut.owner(), address(this));

        // Pending cannot accept from non-pending
        vm.expectRevert();
        uut.acceptOwnership();

        // Now accept from pending
        vm.prank(pending);
        uut.acceptOwnership();
        assertEq(uut.owner(), pending);

        // Original owner can no longer call set
        address[] memory addrs = new address[](1);
        addrs[0] = other;
        vm.expectRevert("Ownable: caller is not the owner");
        uut.set(addrs, true);
    }

    function test_transferOwnership_zero_address_sets_pending_not_transferable() public {
        // Setting zero address as pending owner is allowed in Ownable2Step
        uut.transferOwnership(address(0));
        assertEq(uut.owner(), address(this));
        assertEq(uut.pendingOwner(), address(0));

        // No address can accept; ensure revert from current owner
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        uut.acceptOwnership();
    }
}
