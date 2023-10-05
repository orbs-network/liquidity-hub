// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "src/Treasury.sol";

import "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {UniswapV2Exchange} from "src/exchange/UniswapV2Exchange.sol";

import "./BaseTest.sol";
import "./Workbench.sol";
import "./Treasury.t.sol";

contract TreasuryWithdrawTest is TreasuryTest {
    function testWithdrawOwned() public {
        vm.expectRevert(abi.encodeWithSelector(Treasury.NotAllowed.selector, address(this)));
        treasury.withdraw();
    }

    function testETH() public {
        hoax(owner, 0);
        treasury.withdraw();

        deal(address(treasury), 1 ether);

        assertEq(address(owner).balance, 0);
        hoax(owner, 0);
        treasury.withdraw();

        assertEq(address(owner).balance, 1 ether);
    }

    function testRedirectETH() public {
        hoax(owner, 1 ether);
        Address.sendValue(payable(treasury), 1 ether);
        assertEq(address(treasury).balance, 1 ether);

        hoax(owner, 0);
        treasury.withdraw();
        assertEq(address(treasury).balance, 0);
        assertEq(address(owner).balance, 1 ether);
    }

    function testWETH() public {
        hoax(address(treasury), 1 ether);
        IWETH(config.weth).deposit{value: 1 ether}();

        assertEq(IERC20(config.weth).balanceOf(address(treasury)), 1 ether);
        assertEq(IERC20(config.weth).balanceOf(owner), 0);

        hoax(owner, 0);
        treasury.withdraw();

        assertEq(IERC20(config.weth).balanceOf(owner), 0);
        assertEq(address(owner).balance, 1 ether);
    }

    function testSwapsTokens() public {
        ERC20Mock token = new ERC20Mock();
        token.mint(address(treasury), 1 ether);

        hoax(address(treasury), 1 ether);
        IWETH(config.weth).deposit{value: 1 ether}(); // as if swapped to weth

        address exchange = makeAddr("exchange");
        vm.mockCall(exchange, abi.encodeWithSelector(IExchange.delegateSwap.selector), new bytes(0));

        IExchange.Swap[] memory swaps = new IExchange.Swap[](1);
        swaps[0] = IExchange.Swap({
            exchange: IExchange(exchange),
            token: address(token),
            amount: 1 ether,
            to: exchange,
            data: new bytes(0)
        });

        assertEq(token.balanceOf(owner), 0);
        vm.expectCall(exchange, abi.encodeWithSelector(IExchange.delegateSwap.selector));

        hoax(owner, 0);
        treasury.withdraw(swaps, 0);
        assertEq(token.balanceOf(owner), 0); // swap is mocked, tokens remain in treasury
        assertEq(token.balanceOf(address(treasury)), 1 ether);
        assertEq(address(owner).balance, 1 ether); // from weth
    }

    function testMinAmountOut() public {
        deal(address(treasury), 1.23456 ether);

        assertEq(address(owner).balance, 0);
        vm.expectRevert(abi.encodeWithSelector(Treasury.InsufficientOutput.selector, 1.23456 ether));

        hoax(owner, 0);
        treasury.withdraw(new IExchange.Swap[](0), 999 ether);
    }
}
