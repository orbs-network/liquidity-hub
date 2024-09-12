// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/base/BaseTest.sol";

import {LiquidityHubLib, SignedOrder, IMulticall3} from "src/LiquidityHub.sol";
import {ExclusiveDutchOrder, ExclusiveDutchOrderLib} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

contract LiquidityHubExecuteTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    uint256 inAmount = 1 ether;
    uint256 outAmount = 0.5 ether;
    uint256 gasAmount = 0.01 ether;
    uint256 slippage = 0.03 ether;

    function setUp() public override {
        super.setUp();
        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");
        inToken.mint(swapper, 10 ether);

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function _order() private returns (SignedOrder memory) {
        return signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount);
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
        assertEq(outToken.balanceOf(swapper), outAmount + (slippage / (100 - refshare)));
    }

    function test_nativeOutput() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(swapper.balance, outAmount + (slippage / (100 - refshare)));
    }

    function test_slippageToRef() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(outToken.balanceOf(ref), slippage * refshare / 100);
    }

    function test_longLimit() public {
        vm.warp(block.timestamp + 10 days); // set deadline to be in the future
        SignedOrder memory order = _order();
        vm.warp(block.timestamp - 10 days);

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(outToken.balanceOf(swapper), outAmount + (slippage / (100 - refshare)));
    }

    function test_nativeSlippageToRef() public {
        outToken = ERC20Mock(address(0));

        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(swapper.balance, outAmount + (slippage / (100 - refshare)));
        assertEq(address(config.executor).balance, 0);
        assertEq(ref.balance, slippage * refshare / 100);
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

        assertEq(outToken.balanceOf(swapper), outAmount + (slippage / (100 - refshare)));
    }

    function test_revert_swapperLimit() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        vm.expectRevert(abi.encodeWithSelector(LiquidityHubLib.InvalidOutAmountSwapper.selector, outAmount));
        config.executor.execute(order, calls, outAmount + (slippage / (100 - refshare)) + 1);
    }

    function test_swapperLimitRespectsSurplus() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        config.executor.execute(order, calls, outAmount + 0.001 ether);

        assertEq(outToken.balanceOf(swapper), outAmount + 0.001 ether + ((slippage - 0.001 ether) / (100 - refshare)));
    }

    function test_decayOnNegativeSlippage() public {
        SignedOrder memory order = _order();

        IMulticall3.Call[] memory calls = _mockSwap(); // 50% max negative, 1m decayStart, 2m decayEnd

        vm.warp(block.timestamp + 1.5 minutes); // 50% decay to 50% slippage = -25%

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        uint256 expectedMinOutAmount = outAmount * 75 / 100;
        uint256 expectedTotalSlippage = (outAmount + slippage) - expectedMinOutAmount;
        uint256 expectedSlippage = expectedTotalSlippage / (100 - refshare);
        assertEq(outToken.balanceOf(swapper), expectedMinOutAmount + expectedSlippage);
        assertEq(outToken.balanceOf(ref), expectedTotalSlippage - expectedSlippage);
    }

    function test_inTokenSlippage() public {
        SignedOrder memory order = _order();
        uint256 inTokenSlippage = 0.123 ether;
        inAmount -= inTokenSlippage;
        IMulticall3.Call[] memory calls = _mockSwap();
        inAmount += inTokenSlippage;

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        uint256 expectedInSlippage = inTokenSlippage / (100 - refshare);
        assertEq(inToken.balanceOf(swapper), 9 ether + expectedInSlippage);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(inToken.balanceOf(ref), inTokenSlippage - expectedInSlippage);
        assertEq(outToken.balanceOf(ref), slippage * refshare / 100);
    }

    function test_emitEvents() public {
        SignedOrder memory order = _order();
        IMulticall3.Call[] memory calls = _mockSwap();
        ExclusiveDutchOrder memory o = abi.decode(order.order, (ExclusiveDutchOrder));

        hoax(config.admin.owner());

        vm.expectEmit(address(config.executor));
        emit LiquidityHubLib.Resolved(
            ExclusiveDutchOrderLib.hash(o),
            o.info.swapper,
            ref,
            address(inToken),
            address(outToken),
            inAmount,
            outAmount
        );
        emit LiquidityHubLib.Surplus(o.info.swapper, ref, address(outToken), slippage, refshare);

        config.executor.execute(order, calls, 0);
    }
}
