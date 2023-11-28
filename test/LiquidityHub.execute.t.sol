// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract LiquidityHubExecuteTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;

    function setUp() public override {
        super.setUp();
        (swapper, swapperPK) = makeAddrAndKey("swapper");
    }

    function test_NoSwap_SameToken() public {
        ERC20Mock token = new ERC20Mock();
        uint256 amount = 1 ether;

        hoax(swapper);
        token.approve(PERMIT2_ADDRESS, amount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(token), address(token), amount, amount, 0);

        token.mint(swapper, amount);
        assertEq(token.balanceOf(swapper), amount);

        hoax(config.treasury.owner());
        config.executor.execute(orders, new Call[](0));

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

        hoax(swapper);
        tokenA.approve(PERMIT2_ADDRESS, amountA);
        hoax(swapper2);
        tokenB.approve(PERMIT2_ADDRESS, amountB);

        orders[0] = createAndSignOrder(swapper, swapperPK, address(tokenA), address(tokenB), amountA, amountB, 0);
        orders[1] = createAndSignOrder(swapper2, swapperPK2, address(tokenB), address(tokenA), amountB, amountA, 0);

        assertEq(tokenA.balanceOf(swapper), amountA);
        assertEq(tokenA.balanceOf(swapper2), 0);

        assertEq(tokenB.balanceOf(swapper), 0);
        assertEq(tokenB.balanceOf(swapper2), amountB);

        hoax(config.treasury.owner());
        config.executor.execute(orders, new Call[](0));

        assertEq(tokenA.balanceOf(swapper), 0);
        assertEq(tokenA.balanceOf(swapper2), amountA);

        assertEq(tokenB.balanceOf(swapper), amountB);
        assertEq(tokenB.balanceOf(swapper2), 0);
    }

    function test_Multicall() public {
        ERC20Mock inToken = new ERC20Mock();
        ERC20Mock outToken = new ERC20Mock();
        uint256 inAmount = 1 ether;
        uint256 outAmount = 2 ether;

        hoax(swapper);
        inToken.approve(PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(outToken);
        calls[0].callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(config.executor), outAmount);

        inToken.mint(swapper, inAmount);
        assertEq(inToken.balanceOf(swapper), inAmount);
        assertEq(outToken.balanceOf(swapper), 0);

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(inToken.balanceOf(swapper), 0);
        assertEq(outToken.balanceOf(swapper), outAmount);
    }

    function test_NativeOutput() public {
        IWETH inToken = config.weth;
        address outToken = address(0);
        uint256 inAmount = 1 ether;
        uint256 outAmount = 1 ether;

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(inToken), outToken, inAmount, outAmount, 0);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(inToken);
        calls[0].callData = abi.encodeWithSelector(IWETH.withdraw.selector, outAmount);

        dealWETH(swapper, inAmount);
        assertEq(inToken.balanceOf(swapper), inAmount);
        assertEq(swapper.balance, 0);

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(inToken.balanceOf(swapper), 0);
        assertEq(swapper.balance, outAmount);
    }

    function test_SlippageToFeeRecipient() public {
        ERC20Mock inToken = new ERC20Mock();
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(inToken), address(inToken), inAmount, outAmount, 0);

        inToken.mint(swapper, inAmount);

        hoax(config.treasury.owner());
        config.executor.execute(orders, new Call[](0));

        assertEq(inToken.balanceOf(swapper), outAmount);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(inToken.balanceOf(config.feeRecipient), inAmount - outAmount);
    }

    function test_NativeSlippageToFeeRecipient() public {
        IWETH inToken = config.weth;
        address outToken = address(0);
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(inToken);
        calls[0].callData = abi.encodeWithSelector(IWETH.withdraw.selector, inAmount);

        dealWETH(swapper, inAmount);
        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(swapper.balance, outAmount);
        assertEq(address(config.executor).balance, 0);
        assertEq(config.feeRecipient.balance, inAmount - outAmount);
    }
}
