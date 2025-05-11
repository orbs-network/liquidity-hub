// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IERC20, MockERC20, LiquidityHub} from "test/base/BaseTest.sol";

import {Executor, IAllowed, SignedOrder, IMulticall3} from "src/executor/Executor.sol";

contract ExecutorTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    address public inToken;
    address public outToken;

    uint256 inAmount = 1 ether;
    uint256 outAmount = 0.5 ether;

    Executor public executor;

    function setUp() public override {
        super.setUp();
        executor = new Executor(config.multicall, config.reactor, IAllowed(payable(config.admin)));
        config.executor = LiquidityHub(payable(executor));

        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = address(new MockERC20("inToken", "IN", 18));
        outToken = address(new MockERC20("outToken", "OUT", 18));

        deal(inToken, swapper, 10 ether);

        hoax(swapper, 0);
        IERC20(inToken).approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function _order() private returns (SignedOrder memory) {
        return signedOrder(swapper, swapperPK, inToken, outToken, inAmount, outAmount, 0);
    }

    function mintOutToken() external {
        (address(outToken) == address(0))
            ? deal(address(config.executor), outAmount)
            : deal(outToken, address(config.executor), outAmount);
    }

    function _mockSwap() private view returns (IMulticall3.Call[] memory calls) {
        calls = new IMulticall3.Call[](2);
        calls[0].target = inToken;
        calls[0].callData = abi.encodeWithSelector(IERC20.transfer.selector, address(0), inAmount);
        calls[1].target = address(this);
        calls[1].callData = abi.encodeWithSelector(this.mintOutToken.selector);
    }

    function test_execute() public {
        vm.pauseGasMetering();

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        vm.resumeGasMetering();
        executor.execute(order, abi.encode(calls));
        assertEq(IERC20(outToken).balanceOf(swapper), outAmount);
    }

    function test_nativeOutput() public {
        outToken = address(0);

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        executor.execute(order, abi.encode(calls));

        assertEq(IERC20(inToken).balanceOf(swapper), 9 ether);
        assertEq(swapper.balance, outAmount);
    }

    function test_usdtOutput() public {
        if (block.chainid != 1) return;

        outToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

        SignedOrder memory order = _order();
        deal(address(outToken), address(config.executor), outAmount);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);
        hoax(config.admin.owner());
        executor.execute(order, abi.encode(calls));

        assertEq(IERC20(inToken).balanceOf(swapper), 9 ether);
        assertEq(IERC20(outToken).balanceOf(swapper), outAmount);
    }
}
