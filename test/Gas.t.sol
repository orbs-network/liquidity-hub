// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, SignedOrder, Consts, IMulticall3} from "test/base/BaseTest.sol";

contract GasTest is BaseTest {
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

    function test_singleOrder() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;
        uint256 gasAmount = 0;

        SignedOrder memory order =
            signedOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, gasAmount, ref);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0].target = address(outToken);
        calls[0].callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(config.executor), outAmount);
        calls[1].target = address(this);
        calls[1].callData = abi.encodeWithSelector(BaseTest.wasteGas.selector, 500_000);

        hoax(config.admin.owner());
        config.executor.execute(order, calls, 0);

        assertEq(inToken.balanceOf(swapper), 9 ether);
        assertEq(inToken.balanceOf(address(config.executor)), 0);
        assertEq(outToken.balanceOf(swapper), outAmount);
    }
}
