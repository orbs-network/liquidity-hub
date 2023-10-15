// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/BaseTest.sol";

import {LiquidityHub, IReactor, IExchange, ResolvedOrder, SignedOrder} from "src/LiquidityHub.sol";

contract LiquidityHubAccessTest is BaseTest {
    LiquidityHub public uut;

    function setUp() public withMockConfig {
        uut = new LiquidityHub(config.reactor, config.treasury);
        vm.mockCall(
            address(config.reactor), abi.encodeWithSelector(IReactor.executeWithCallback.selector), new bytes(0)
        );
    }

    function test_Execute_OnlyAllowed() public {
        SignedOrder memory order;
        hoax(config.treasury.owner());
        uut.execute(order, new IExchange.Swap[](0));
    }

    function test_Revert_Execute_OnlyAllowed() public {
        SignedOrder memory order;
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        uut.execute(order, new IExchange.Swap[](0));
    }

    function test_ExecuteBatch_OnlyAllowed() public {
        hoax(config.treasury.owner());
        uut.executeBatch(new SignedOrder[](0), new IExchange.Swap[](0));
    }

    function test_Revert_ExecuteBatch_OnlyAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        uut.executeBatch(new SignedOrder[](0), new IExchange.Swap[](0));
    }

    function test_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        uut.validate(address(uut), order);
        assertTrue(true);
    }

    function test_Revert_ValidationCallback_OnlySelf() public {
        ResolvedOrder memory order;
        address filler = makeAddr("unknown filler");
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, filler));
        uut.validate(filler, order);
    }

    function test_ReactorCallback_OnlyReactor() public {
        hoax(address(config.reactor));
        uut.reactorCallback(new ResolvedOrder[](0), abi.encode(new IExchange.Swap[](0)));
    }

    function test_Revert_ReactorCallback_OnlyReactor() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        uut.reactorCallback(new ResolvedOrder[](0), abi.encode(new IExchange.Swap[](0)));
    }
}
