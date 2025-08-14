// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Vm} from "forge-std/Vm.sol";

import {BaseTest} from "./base/BaseTest.sol";
import {Refinery, IAdmin} from "../src/Refinery.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {Admin} from "../src/Admin.sol";

contract RefineryTest is BaseTest {
    Refinery internal refinery;
    address internal bob = address(2);

    event Refined(address indexed token, address indexed recipient, uint256 amount);

    function setUp() public virtual override {
        super.setUp();
        refinery = new Refinery(multicall, admin);
    }

    function _allowMe() private {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, true);
    }

    function test_cant_execute_if_not_allowed() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, false);
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](0);
        vm.expectRevert(Refinery.NotAllowed.selector);
        refinery.execute(calls);
    }

    function test_cant_transfer_if_not_allowed() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, false);
        vm.expectRevert(Refinery.NotAllowed.selector);
        refinery.transfer(address(token), bob, 100);
    }

    function test_execute() public {
        _allowMe();
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](1);
        calls[0] = IMulticall3.Call3({
            target: address(token),
            allowFailure: false,
            callData: abi.encodeWithSignature("mint(address,uint256)", bob, 1e18)
        });
        refinery.execute(calls);
        assertEq(token.balanceOf(bob), 1e18);
    }

    function test_execute_empty_calls_ok() public {
        _allowMe();
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](0);
        refinery.execute(calls);
        // nothing to assert beyond not reverting
    }

    function test_execute_call_failure_allowFailure_true_does_not_revert() public {
        _allowMe();
        // Attempt to transfer tokens from refinery without balance -> underlying call fails
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](1);
        calls[0] = IMulticall3.Call3({
            target: address(token),
            allowFailure: true,
            callData: abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18)
        });
        refinery.execute(calls);
    }

    function test_execute_call_failure_allowFailure_false_reverts() public {
        _allowMe();
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](1);
        calls[0] = IMulticall3.Call3({
            target: address(token),
            allowFailure: false,
            callData: abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18)
        });
        vm.expectRevert();
        refinery.execute(calls);
    }

    function test_transfer_eth() public {
        _allowMe();
        vm.deal(address(refinery), 1e18);
        uint256 bobBalanceBefore = bob.balance;
        refinery.transfer(address(0), bob, 5_000); // 50%
        assertEq(bob.balance, bobBalanceBefore + 0.5e18);
    }

    function test_transfer_eth_bps_zero_noop() public {
        _allowMe();
        vm.deal(address(refinery), 1e18);
        uint256 bobBalanceBefore = bob.balance;
        refinery.transfer(address(0), bob, 0); // 0%
        assertEq(bob.balance, bobBalanceBefore);
    }

    function test_transfer_eth_bps_full() public {
        _allowMe();
        vm.deal(address(refinery), 1e18);
        refinery.transfer(address(0), bob, 10_000); // 100%
        assertEq(bob.balance, 1e18);
    }

    function test_transfer_eth_zero_balance() public {
        _allowMe();
        uint256 bobBalanceBefore = bob.balance;
        refinery.transfer(address(0), bob, 5_000); // 50%
        assertEq(bob.balance, bobBalanceBefore);
    }

    function test_transfer_erc20() public {
        _allowMe();
        token.mint(address(refinery), 1e18);
        refinery.transfer(address(token), bob, 5_000); // 50%
        assertEq(token.balanceOf(bob), 0.5e18);
    }

    function test_transfer_erc20_bps_zero_noop() public {
        _allowMe();
        token.mint(address(refinery), 1e18);
        refinery.transfer(address(token), bob, 0); // 0%
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transfer_erc20_bps_full() public {
        _allowMe();
        token.mint(address(refinery), 1e18);
        refinery.transfer(address(token), bob, 10_000); // 100%
        assertEq(token.balanceOf(bob), 1e18);
    }

    function test_transfer_erc20_zero_balance() public {
        _allowMe();
        refinery.transfer(address(token), bob, 5_000); // 50%
        assertEq(token.balanceOf(bob), 0);
    }

    function test_receive() public {
        (bool success,) = address(refinery).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(refinery).balance, 1 ether);
    }

    function test_event_refined_eth() public {
        _allowMe();
        vm.deal(address(refinery), 1e18);
        vm.expectEmit(true, true, true, true);
        emit Refined(address(0), bob, 0.5e18);
        refinery.transfer(address(0), bob, 5_000); // 50%
    }

    function test_no_event_when_amount_zero_eth() public {
        _allowMe();
        vm.recordLogs();
        refinery.transfer(address(0), bob, 0); // 0%
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // No Refined event should be emitted
        assertEq(entries.length, 0);
    }

    function test_event_refined_erc20() public {
        _allowMe();
        token.mint(address(refinery), 1e18);
        vm.expectEmit(true, true, true, true);
        emit Refined(address(token), bob, 0.5e18);
        refinery.transfer(address(token), bob, 5_000); // 50%
    }

    function test_no_event_when_amount_zero_erc20() public {
        _allowMe();
        vm.recordLogs();
        refinery.transfer(address(token), bob, 0); // 0%
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);
    }
}
