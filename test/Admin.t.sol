// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Vm} from "forge-std/Vm.sol";

import "forge-std/Test.sol";

import {BaseTest, IMulticall3, ERC20Mock} from "test/base/BaseTest.sol";

import {Admin} from "src/Admin.sol";

contract AdminTest is BaseTest {
    Admin public uut;

    // Duplicate event signature for expectEmit matching
    event AllowedSet(address indexed addr, bool allowed);

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

    function test_emit_allowed_set_allow_and_revoke() public {
        address a = makeAddr("a");
        address[] memory addrs = new address[](1);
        addrs[0] = a;

        // expect allow
        vm.expectEmit(address(uut));
        emit AllowedSet(a, true);
        uut.set(addrs, true);
        assertEq(uut.allowed(a), true);

        // expect revoke
        vm.expectEmit(address(uut));
        emit AllowedSet(a, false);
        uut.set(addrs, false);
        assertEq(uut.allowed(a), false);
    }

    function test_set_multiple_addresses() public {
        address a = makeAddr("a");
        address b = makeAddr("b");
        address c = makeAddr("c");

        address[] memory addrs = new address[](3);
        addrs[0] = a;
        addrs[1] = b;
        addrs[2] = c;

        // expect three events in order
        vm.expectEmit(address(uut));
        emit AllowedSet(a, true);
        vm.expectEmit(address(uut));
        emit AllowedSet(b, true);
        vm.expectEmit(address(uut));
        emit AllowedSet(c, true);

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

    function test_set_no_events_on_empty_array() public {
        // Record logs and ensure calling set with empty array emits no events
        vm.recordLogs();
        address[] memory none = new address[](0);
        uut.set(none, true);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);
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

    function test_set_with_duplicate_addresses_emits_twice_and_idempotent() public {
        address a = makeAddr("dup");
        address[] memory addrs = new address[](2);
        addrs[0] = a;
        addrs[1] = a; // duplicate

        // Expect two events for the same address since loop emits per entry
        vm.expectEmit(address(uut));
        emit AllowedSet(a, true);
        vm.expectEmit(address(uut));
        emit AllowedSet(a, true);

        uut.set(addrs, true);
        assertEq(uut.allowed(a), true);

        // Now revoke twice as well
        vm.expectEmit(address(uut));
        emit AllowedSet(a, false);
        vm.expectEmit(address(uut));
        emit AllowedSet(a, false);
        uut.set(addrs, false);
        assertEq(uut.allowed(a), false);
    }
}
