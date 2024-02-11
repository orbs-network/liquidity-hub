// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH, SignedOrder, Call} from "test/base/BaseTest.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";
import {PartialOrderReactor, RePermit} from "src/PartialOrderReactor.sol";

contract PartialOrderReactorTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    ERC20Mock public inToken;
    ERC20Mock public outToken;
    uint256 public inAmountSwapperStart = 10 ether;

    function setUp() public override {
        super.setUp();

        vm.etch(
            address(config.executor),
            address(new LiquidityHub(config.reactorPartial, config.treasury, config.fees)).code
        );

        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        inToken.mint(swapper, inAmountSwapperStart);
        hoax(swapper);
        inToken.approve(address(config.repermit), type(uint256).max);
    }

    function test_Execute_SwapTheFullAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountRequest = inAmount;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, inAmountRequest, outAmount);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inAmountSwapperStart - inAmountRequest, "swapper inToken");
    }

    function test_Execute_SwapTwice() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountRequest = 0.5 ether; // 50%
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, inAmountRequest, outAmount);

        assertEq(outToken.balanceOf(swapper), 0.25 ether, "swapper end outAmount, swap1");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inAmountSwapperStart - inAmountRequest, "swapper inToken");

        _execute(inAmount, inAmountRequest, outAmount);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount, swap2");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inAmountSwapperStart - inAmount, "swapper inToken");
    }

    function test_Execute_SwapPartialAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountRequest = 0.4 ether; // 40%
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, inAmountRequest, outAmount);

        assertEq(outToken.balanceOf(swapper), 0.2 ether, "swapper end outAmount");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inAmountSwapperStart - inAmountRequest, "swapper inToken");
    }

    function test_Revert_inAmountRequestGreaterThanInAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountRequest = 1 ether + 1;
        uint256 outAmount = 0.5 ether;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, inAmountRequest, outAmount
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(inToken);
        tokens[1] = address(outToken);

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0));
        config.executor.execute(orders, mockSwapCalls(inToken, outToken, inAmountRequest, outAmount), tokens);
    }

    function test_Revert_InsufficentAlowanceAfterSpending() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountRequest = 0.75 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, inAmountRequest, outAmount);

        assertEq(inToken.balanceOf(address(swapper)), inAmountSwapperStart - inAmountRequest, "no inToken leftovers");

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, inAmountRequest, outAmount
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(inToken);
        tokens[1] = address(outToken);

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0.75 ether));
        config.executor.execute(orders, mockSwapCalls(inToken, outToken, inAmountRequest, outAmount), tokens);
    }

    function _execute(uint256 inAmount, uint256 inAmountRequest, uint256 outAmount) private {
        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, inAmountRequest, outAmount
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(inToken);
        tokens[1] = address(outToken);

        hoax(config.treasury.owner());
        config.executor.execute(orders, mockSwapCalls(inToken, outToken, inAmountRequest, outAmount), tokens);
    }
}
