// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock} from "test/BaseTest.sol";

import {
    LiquidityHub,
    IValidationCallback,
    IReactor,
    IExchange,
    IERC20,
    ResolvedOrder,
    SignedOrder
} from "src/LiquidityHub.sol";

contract LiquidityHubExecuteTest is BaseTest {
    LiquidityHub public liquidityHub;
    address swapper;

    function setUp() public withMockConfig {
        liquidityHub = new LiquidityHub(config.reactor, config.treasury);
        swapper = makeAddr("swapper");
    }

    function test_NoOp() public {
        hoax(config.treasury.owner());
        // liquidityHub.executeBatch(new SignedOrder[](0), new IExchange.Swap[](0));
    }

    // function test_NoSwap_SameToken() public {
    // IERC20 token = new ERC20Mock();
    // uint256 inAmount = 1 ether;
    // bytes memory sig = abi.encodePacked("signature");

    // orders[0] = MockReactor(address(config.reactor)).createOrder({
    //     swapper: swapper,
    //     inToken: address(token),
    //     inAmount: inAmount,
    //     outToken: address(token),
    //     outAmount: inAmount,
    //     sig: sig
    // });

    // hoax(config.treasury.owner());
    // liquidityHub.executeBatch(orders, new IExchange.Swap[](0));
    // }

    // function test_NoSwaps_MirrorOrders() public {
    //     SignedOrder[] memory orders = new SignedOrder[](2);

    //     hoax(config.treasury.owner());
    //     liquidityHub.executeBatch(orders, new IExchange.Swap[](0));
    // }
}
