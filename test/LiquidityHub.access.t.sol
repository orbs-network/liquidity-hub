// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {LiquidityHub, LiquidityHubLib, IReactor, ResolvedOrder, SignedOrder, IMulticall3} from "src/LiquidityHub.sol";

contract LiquidityHubAccessTest is BaseTest {
    address public owner;
    LiquidityHub public uut;

    function setUp() public override {
        super.setUp();
        owner = config.admin.owner();
        uut = config.executor;
        vm.mockCall(
            address(config.reactor), abi.encodeWithSelector(IReactor.executeWithCallback.selector), new bytes(0)
        );
    }

    function test_revert_execute_onlyAllowed() public {
        SignedOrder memory order;
        vm.expectRevert(abi.encodeWithSelector(LiquidityHubLib.InvalidSender.selector, address(this)));
        uut.execute(order, new IMulticall3.Call[](0), 0);
    }

    function test_revert_validationCallback_noRef() public {
        ResolvedOrder memory order;
        vm.expectRevert(abi.encodeWithSelector(LiquidityHubLib.InvalidOrder.selector));
        uut.validate(address(uut), order);
    }

    function test_revert_validationCallback_onlySelf() public {
        ResolvedOrder memory order;
        address filler = makeAddr("unknown filler");
        vm.expectRevert(abi.encodeWithSelector(LiquidityHubLib.InvalidSender.selector, filler));
        config.executor.validate(filler, order);
    }

    function test_revert_reactorCallback_onlyReactor() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHubLib.InvalidSender.selector, address(this)));
        config.executor.reactorCallback(new ResolvedOrder[](0), abi.encode(new IMulticall3.Call[](0)));
    }
}
