// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, IMulticall3} from "src/LiquidityHub.sol";

contract LiquidityHubExecuteTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    address public ref;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    uint256 inAmount = 1 ether;
    uint256 outAmount = 0.5 ether;
    uint256 gasAmount = 0.01 ether;
    uint256 slippage = 0.03 ether;

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

    function test_gas() public {
        vm.pauseGasMetering();

        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);
        outToken.mint(address(config.executor), outAmount + gasAmount + slippage);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);
        hoax(config.admin.owner());
        vm.resumeGasMetering();

        config.executor.execute(order, calls, 0);
    }

    function test_nativeOutput() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = address(vm);
        calls[0].callData =
            abi.encodeWithSelector(vm.deal.selector, address(config.executor), outAmount + gasAmount + slippage);

        assertEq(inToken.balanceOf(swapper), 10 ether);
        assertEq(swapper.balance, 0);

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(swapper.balance, outAmount);
    }

    function test_slippageToRef() public {
        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = address(outToken);
        calls[0].callData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(config.executor), outAmount + gasAmount + slippage);

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(outToken.balanceOf(ref), slippage);
    }

    function test_longLimit() public {
        vm.warp(block.timestamp + 10 days); // set deadline to be in the future
        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);
        vm.warp(block.timestamp - 10 days);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = address(outToken);
        calls[0].callData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(config.executor), outAmount + gasAmount + slippage);

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(outToken.balanceOf(swapper), outAmount);
    }

    function test_nativeSlippageToRef() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = address(vm);
        calls[0].callData =
            abi.encodeWithSelector(vm.deal.selector, address(config.executor), outAmount + gasAmount + slippage);

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(swapper.balance, outAmount);
        assertEq(address(config.executor).balance, 0);
        assertEq(ref.balance, slippage);
    }

    function test_gasToAdmin() public {
        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(outToken),
            callData: abi.encodeWithSelector(
                ERC20Mock.mint.selector, address(config.executor), outAmount + gasAmount + slippage
            )
        });
        calls[1] = IMulticall3.Call({
            target: address(inToken),
            callData: abi.encodeWithSelector(ERC20Mock.burn.selector, address(config.executor), inAmount)
        });

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(outToken.balanceOf(swapper), outAmount, "swapper outToken");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no dust");
        assertEq(outToken.balanceOf(address(config.admin)), gasAmount, "gas fee");
        assertEq(outToken.balanceOf(ref), slippage, "slippage");
    }
}
