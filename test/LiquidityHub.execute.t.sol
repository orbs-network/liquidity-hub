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

    function _order() private returns (SignedOrder memory) {
        return signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);
    }

    function _mockSwap() private view returns (IMulticall3.Call[] memory calls) {
        calls = new IMulticall3.Call[](2);
        calls[0].target = address(inToken);
        calls[0].callData = abi.encodeWithSelector(ERC20Mock.burn.selector, address(config.executor), inAmount);
        calls[1].target = (address(outToken) == address(0)) ? address(vm) : address(outToken);
        calls[1].callData = abi.encodeWithSelector(
            (address(outToken) == address(0)) ? vm.deal.selector : ERC20Mock.mint.selector,
            address(config.executor),
            outAmount + gasAmount + slippage
        );
    }

    function test_gas() public {
        vm.pauseGasMetering();

        SignedOrder memory order = _order();

        outToken.mint(address(config.executor), outAmount + gasAmount + slippage);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);

        hoax(config.admin.owner());
        vm.resumeGasMetering();
        config.executor.execute(order, calls, 0);
        assertEq(outToken.balanceOf(swapper), outAmount);
    }

    function test_nativeOutput() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(swapper.balance, outAmount);
    }

    function test_slippageToRef() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(outToken.balanceOf(ref), slippage);
    }

    function test_longLimit() public {
        vm.warp(block.timestamp + 10 days); // set deadline to be in the future
        SignedOrder memory order = _order();
        vm.warp(block.timestamp - 10 days);

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(outToken.balanceOf(swapper), outAmount);
    }

    function test_nativeSlippageToRef() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(swapper.balance, outAmount);
        assertEq(address(config.executor).balance, 0);
        assertEq(ref.balance, slippage);
    }

    function test_gasToAdmin() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);
        assertEq(outToken.balanceOf(address(config.admin)), gasAmount);
    }

    function test_swapperLimit() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, outAmount);

        assertEq(outToken.balanceOf(swapper), outAmount);
    }

    function test_revert_swapperLimit() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSwapperLimit.selector, outAmount));
        config.executor.execute(order, calls, outAmount + 1);
    }

    function test_decayOnNegativeSlippage() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap(); // 50% max negative, 1m decayStart, 2m decayEnd

        vm.warp(block.timestamp + 1.5 minutes); // 50% decay to 50% slippage = -25%

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(outToken.balanceOf(swapper), outAmount * 75 / 100);
    }
}
