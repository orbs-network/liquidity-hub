// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/BaseTest.sol";

import {LiquidityHub, IReactor, IExchange, ResolvedOrder, SignedOrder} from "src/LiquidityHub.sol";

contract LiquidityHubAccessTest is BaseTest {
    LiquidityHub public liquidityHub;

    function setUp() public withMockConfig {
        liquidityHub = new LiquidityHub(config.reactor, config.treasury);
    }

    function test_Execute_OnlyAllowed() public {
        SignedOrder memory order;
        vm.mockCall(
            address(config.reactor), abi.encodeWithSelector(IReactor.executeBatchWithCallback.selector), new bytes(0)
        );
        hoax(config.treasury.owner());
        liquidityHub.execute(order, new IExchange.Swap[](0));
    }

    function test_Revert_Execute_OnlyAllowed() public {
        SignedOrder memory order;
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        liquidityHub.execute(order, new IExchange.Swap[](0));
    }

    function test_ExecuteBatch_OnlyAllowed() public {
        vm.mockCall(
            address(config.reactor), abi.encodeWithSelector(IReactor.executeBatchWithCallback.selector), new bytes(0)
        );
        hoax(config.treasury.owner());
        liquidityHub.executeBatch(new SignedOrder[](0), new IExchange.Swap[](0));
    }

    function test_Revert_ExecuteBatch_OnlyAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        liquidityHub.executeBatch(new SignedOrder[](0), new IExchange.Swap[](0));
    }

    function test_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        liquidityHub.validate(address(liquidityHub), order);
        assertTrue(true);
    }

    function test_Revert_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        address filler = makeAddr("unknown filler");
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, filler));
        liquidityHub.validate(filler, order);
    }

    function test_ReactorCallback_OnlyReactor() public {
        hoax(address(config.reactor));
        liquidityHub.reactorCallback(new ResolvedOrder[](0), abi.encode(new IExchange.Swap[](0)));
        assertTrue(true);
    }

    function test_Revert_ReactorCallback_OnlyReactor() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        liquidityHub.reactorCallback(new ResolvedOrder[](0), abi.encode(new IExchange.Swap[](0)));
    }
}
