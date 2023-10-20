// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/BaseTest.sol";

import {LiquidityHub, IReactor, ResolvedOrder, SignedOrder, Call} from "src/LiquidityHub.sol";

contract LiquidityHubAccessTest is BaseTest {
    function setUp() public withMockConfig {
        vm.mockCall(
            address(config.reactor), abi.encodeWithSelector(IReactor.executeWithCallback.selector), new bytes(0)
        );
    }

    function test_Execute_OnlyAllowed() public {
        hoax(config.treasury.owner());
        config.executor.execute(new SignedOrder[](0), new Call[](0), new address[](0));
    }

    function test_Revert_Execute_OnlyAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        config.executor.execute(new SignedOrder[](0), new Call[](0), new address[](0));
    }

    function test_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        config.executor.validate(address(config.executor), order);
        assertTrue(true);
    }

    function test_Revert_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        address filler = makeAddr("unknown filler");
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, filler));
        config.executor.validate(filler, order);
    }

    function test_ReactorCallback_OnlyReactor() public {
        hoax(address(config.reactor));
        config.executor.reactorCallback(new ResolvedOrder[](0), abi.encode(new Call[](0)));
    }

    function test_Revert_ReactorCallback_OnlyReactor() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        config.executor.reactorCallback(new ResolvedOrder[](0), abi.encode(new Call[](0)));
    }
}
