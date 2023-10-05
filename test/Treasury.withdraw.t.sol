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

    function testTokens() public {
        ERC20Mock token = new ERC20Mock();
        token.mint(address(treasury), 1 ether);

        assertEq(token.balanceOf(owner), 0);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = token;

        hoax(owner, 0);
        treasury.withdraw(tokens);
        assertEq(token.balanceOf(owner), 1 ether);
    }
}
