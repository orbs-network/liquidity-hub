// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract LiquidityHubExecuteTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    address public ref;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    function setUp() public override {
        super.setUp();
        (swapper, swapperPK) = makeAddrAndKey("swapper");
        ref = makeAddr("ref");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");
        inToken.mint(swapper, 10 ether);

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function test_noOp() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 1 ether;
        uint256 gasAmount = 0;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = signedOrder(swapper, swapperPK, address(inToken), address(inToken), inAmount, outAmount, gasAmount, ref);

        assertEq(inToken.balanceOf(swapper), 10 ether);
        assertEq(outToken.balanceOf(swapper), 0);

        hoax(config.admin.owner());
        config.executor.execute(orders, new Call[](0));

        assertEq(inToken.balanceOf(swapper), 10 ether);
        assertEq(outToken.balanceOf(swapper), 0);
    }

    function test_mirrorOrders() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 2 ether;
        uint256 gasAmount = 0;
        (address swapper2, uint256 swapperPK2) = makeAddrAndKey("swapper2");

        outToken.mint(swapper2, outAmount);
        hoax(swapper2);
        outToken.approve(PERMIT2_ADDRESS, outAmount);

        SignedOrder[] memory orders = new SignedOrder[](2);
        orders[0] = signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);
        orders[1] = signedOrder(swapper2, swapperPK2, address(outToken), address(inToken), outAmount, inAmount, gasAmount, ref);

        assertEq(inToken.balanceOf(swapper), 10 ether);
        assertEq(inToken.balanceOf(swapper2), 0);

        assertEq(outToken.balanceOf(swapper), 0);
        assertEq(outToken.balanceOf(swapper2), outAmount);

        hoax(config.admin.owner());
        config.executor.execute(orders, new Call[](0));

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(swapper2), inAmount);

        assertEq(outToken.balanceOf(swapper), outAmount);
        assertEq(outToken.balanceOf(swapper2), 0);
    }

    function test_nativeOutput() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 2 ether;
        uint256 gasAmount = 0;
        outToken = ERC20Mock(address(0));

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(vm);
        calls[0].callData = abi.encodeWithSelector(vm.deal.selector, address(config.executor), outAmount);

        assertEq(inToken.balanceOf(swapper), 10 ether);
        assertEq(swapper.balance, 0);

        hoax(config.admin.owner());
        config.executor.execute(orders, calls);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(swapper.balance, outAmount);
    }

    function test_slippageToRef() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;
        uint256 gasAmount = 0;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(outToken);
        calls[0].callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(config.executor), outAmount + 123456);

        hoax(config.admin.owner());
        config.executor.execute(orders, calls);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(outToken.balanceOf(ref), 123456);
    }

    function test_nativeSlippageToRef() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.7 ether;
        uint256 gasAmount = 0;
        outToken = ERC20Mock(address(0));

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(vm);
        calls[0].callData = abi.encodeWithSelector(vm.deal.selector, address(config.executor), outAmount + 123456);

        hoax(config.admin.owner());
        config.executor.execute(orders, calls);

        assertEq(swapper.balance, outAmount);
        assertEq(address(config.executor).balance, 0);
        assertEq(ref.balance, 123456);
    }

    function test_gasToAdmin() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;
        uint256 gasAmount = 0.25 ether;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = signedOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref
        );

        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(outToken),
            callData: abi.encodeWithSelector(
                ERC20Mock.mint.selector, address(config.executor), outAmount + gasAmount + 123 // random slippage
                )
        });
        calls[1] = Call({
            target: address(inToken),
            callData: abi.encodeWithSelector(ERC20Mock.burn.selector, address(config.executor), inAmount)
        });

        hoax(config.admin.owner());
        config.executor.execute(orders, calls);

        assertEq(outToken.balanceOf(swapper), outAmount, "swapper outToken");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no dust");
        assertEq(outToken.balanceOf(address(config.admin)), gasAmount, "gas fee");
        assertEq(outToken.balanceOf(ref), 123, "slippage");
    }
}
