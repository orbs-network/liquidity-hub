// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "./Workbench.sol";

import "./LiquidityHub.t.sol";

contract LiquidityHubWithdraw is LiquidityHubTest {
    using Workbench for Vm;

    ERC20Mock public token;

    function setUp() public override {
        super.setUp();
        token = new ERC20Mock();
    }

    function testETH() public {
        deal(address(liquidityHub), 1 ether);

        hoax(owner, 0);
        liquidityHub.withdraw(new IExchange.Swap[](0), new address[](0), 0);
        assertEq(address(owner).balance, 1 ether);
    }

    function testWETH() public {
        hoax(address(liquidityHub), 1 ether);
        WETH(payable(config.weth)).deposit{value: 1 ether}();

        assertEq(IERC20(config.weth).balanceOf(owner), 0);
        hoax(owner, 0);
        liquidityHub.withdraw(new IExchange.Swap[](0), new address[](0), 0);
        assertEq(IERC20(config.weth).balanceOf(owner), 0);
        assertEq(address(owner).balance, 1 ether);
    }

    function testToken() public {
        token.mint(address(liquidityHub), 1 ether);

        assertEq(token.balanceOf(owner), 0);
        hoax(owner, 0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);
        liquidityHub.withdraw(new IExchange.Swap[](0), tokens, 0);
        assertEq(token.balanceOf(owner), 1 ether);
    }

    function testMultiple() public {
        token.mint(address(liquidityHub), 123 ether);
        hoax(owner, 456 ether);
    }
}
