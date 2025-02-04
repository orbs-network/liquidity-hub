// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IERC20, Consts, Admin} from "test/base/BaseTest.sol";

import {Executor, IAllowed, SignedOrder, IMulticall3, ResolvedOrder} from "src/Executor.sol";

contract ExecutorAccessTest is BaseTest {
    Executor public executor;

    function setUp() public override {
        IAllowed allowed = IAllowed(payable(new Admin(makeAddr("owner"))));
        executor = new Executor(Consts.MULTICALL_ADDRESS, config.reactor, allowed);
    }

    function test_revert_execute_onlyAllowed() public {
        SignedOrder memory order;
        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, address(this)));
        executor.execute(order, abi.encode(new IMulticall3.Call[](0)));
    }

    function test_revert_validationCallback_onlySelf() public {
        ResolvedOrder memory order;
        address filler = makeAddr("unknown filler");
        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, filler));
        executor.validate(filler, order);
    }

    function test_revert_reactorCallback_onlyReactor() public {
        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, address(this)));
        executor.reactorCallback(new ResolvedOrder[](0), abi.encode(new IMulticall3.Call[](0)));
    }
}
