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

    function setUp() public override {
        super.setUp();

        vm.etch(address(config.executor), address(new LiquidityHub(config.reactorPartial, config.treasury)).code);

        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        inToken.mint(swapper, 10 ether);
        hoax(swapper);
        inToken.approve(address(config.repermit), type(uint256).max);
    }

    function test_Execute_SwapFullAmount() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.5 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
    }

    function test_Execute_SwapPartial() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9.5 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.25 ether, "swapper end outAmount, swap1");

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount, swap2");
    }

    function test_Execute_SwapPartialOdd() public {
        uint256 inAmount = 10 ether;
        uint256 outAmount = 30 ether;

        _execute(inAmount, outAmount, 7 ether);

        assertEq(inToken.balanceOf(address(swapper)), 10 ether - 2333333333333333333, "swapper inToken"); // floor the input
        assertEq(outToken.balanceOf(swapper), 7 ether, "swapper end outAmount");
    }

    function test_Revert_RequestGreaterThanSigned() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0.6 ether
        );

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0));
        config.executor.execute(orders, mockSwapCalls(inToken, outToken, 0, 0.6 ether), address(0), new address[](0));
    }

    function test_Revert_InsufficentAlowanceAfterSpending() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9.5 ether, "no inToken leftovers");

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0.5 ether
        );

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0.5 ether));
        config.executor.execute(orders, mockSwapCalls(inToken, outToken, 0, 0.5 ether), address(0), new address[](0));
    }

    function _execute(uint256 inAmount, uint256 outAmount, uint256 fillOutAmount) private {
        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, fillOutAmount
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(inToken);
        tokens[1] = address(outToken);

        hoax(config.treasury.owner());
        config.executor.execute(
            orders,
            mockSwapCalls(inToken, outToken, (inAmount * fillOutAmount) / outAmount, fillOutAmount),
            address(0),
            tokens
        );

        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
    }
}
