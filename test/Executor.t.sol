// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IERC20, Consts, MockERC20} from "test/base/BaseTest.sol";

import {Executor, SignedOrder, IMulticall3} from "src/Executor.sol";

contract LiquidityHubExecuteTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    address public inToken;
    address public outToken;

    uint256 inAmount = 1 ether;
    uint256 outAmount = 0.5 ether;

    Executor public executor;

    function setUp() public override {
        super.setUp();
        executor = new Executor(Consts.MULTICALL_ADDRESS, config.reactor);

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

    function test_gas() public {
        vm.pauseGasMetering();

        SignedOrder memory order = _order();

        deal(outToken, address(config.executor), outAmount);

        IMulticall3.Call[] memory calls = _mockSwap();

        hoax(config.admin.owner());
        vm.resumeGasMetering();
        executor.execute(order, abi.encode(calls));
        assertEq(IERC20(outToken).balanceOf(swapper), outAmount);
    }
}
