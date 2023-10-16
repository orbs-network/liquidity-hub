// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock} from "test/BaseTest.sol";

import {LiquidityHub, IValidationCallback, IReactor, IExchange, IERC20, SignedOrder} from "src/LiquidityHub.sol";

contract LiquidityHubExecuteTest is BaseTest {
    LiquidityHub public liquidityHub;
    address public swapper;
    uint256 public swapperPK;

    function setUp() public withMockConfig withExclusiveDutchOrderReactor {
        liquidityHub = new LiquidityHub(config.reactor, config.treasury);
        (swapper, swapperPK) = makeAddrAndKey("swapper");
    }

    function test_NoSwap_SameToken() public {
        ERC20Mock token = new ERC20Mock();
        uint256 amount = 1 ether;

        token.mint(swapper, amount);
        assertEq(token.balanceOf(swapper), amount);

        hoax(swapper);
        token.approve(PERMIT2_ADDRESS, amount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createOrder(swapper, swapperPK, address(token), amount, address(token), amount);

        hoax(config.treasury.owner());
        liquidityHub.executeBatch(orders, new IExchange.Swap[](0));

        assertEq(token.balanceOf(swapper), amount);
    }

    function test_NoSwap_MirrorOrders() public {
        (address swapper2, uint256 swapperPK2) = makeAddrAndKey("swapper2");

        SignedOrder[] memory orders = new SignedOrder[](2);

        ERC20Mock tokenA = new ERC20Mock();
        ERC20Mock tokenB = new ERC20Mock();

        uint256 amountA = 1 ether;
        uint256 amountB = 2 ether;

        tokenA.mint(swapper, amountA);
        tokenB.mint(swapper2, amountB);

        assertEq(tokenA.balanceOf(swapper), amountA);
        assertEq(tokenA.balanceOf(swapper2), 0);

        assertEq(tokenB.balanceOf(swapper), 0);
        assertEq(tokenB.balanceOf(swapper2), amountB);

        hoax(swapper);
        tokenA.approve(PERMIT2_ADDRESS, amountA);
        hoax(swapper2);
        tokenB.approve(PERMIT2_ADDRESS, amountB);

        orders[0] = createOrder(swapper, swapperPK, address(tokenA), amountA, address(tokenB), amountB);
        orders[1] = createOrder(swapper2, swapperPK2, address(tokenB), amountB, address(tokenA), amountA);

        hoax(config.treasury.owner());
        liquidityHub.executeBatch(orders, new IExchange.Swap[](0));

        assertEq(tokenA.balanceOf(swapper), 0);
        assertEq(tokenA.balanceOf(swapper2), amountA);

        assertEq(tokenB.balanceOf(swapper), amountB);
        assertEq(tokenB.balanceOf(swapper2), 0);
    }
}
