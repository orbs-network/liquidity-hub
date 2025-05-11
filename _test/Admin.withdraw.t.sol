// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IERC20, ERC20Mock} from "test/base/BaseTest.sol";

import {Admin, IMulticall3} from "src/Admin.sol";
import {IWETH} from "src/interface/IWETH.sol";

contract AdminWithdrawTest is BaseTest {
    address owner;
    Admin admin;

    function setUp() public override {
        super.setUp();
        admin = config.admin;
        owner = admin.owner();
    }

    function test_empty() public {
        hoax(owner, 0);
        admin.withdraw(new IERC20[](0));
        assertEq(owner.balance, 0);
    }

    function test_ETH() public {
        deal(address(admin), 1 ether);
        hoax(owner, 0);
        admin.withdraw(new IERC20[](0));
        assertEq(owner.balance, 1 ether);
    }

    function test_WETH() public {
        IWETH w = admin.weth();
        hoax(address(admin), 1 ether);
        w.deposit{value: 1 ether}();
        hoax(owner, 0);
        admin.withdraw(new IERC20[](0));
        assertEq(owner.balance, 1 ether);
    }

    function test_tokens() public {
        ERC20Mock token = new ERC20Mock();
        token.mint(address(admin), 1 ether);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = token;

        hoax(owner, 0);
        admin.withdraw(tokens);
        assertEq(token.balanceOf(owner), 1 ether);
    }

    function test_execute() public {
        ERC20Mock token = new ERC20Mock();
        token.mint(address(admin), 1 ether);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0].target = address(token);
        calls[0].callData = abi.encodeWithSelector(IERC20.transfer.selector, owner, 1 ether);

        hoax(owner, 0);
        admin.execute(calls);
        assertEq(token.balanceOf(owner), 1 ether);
    }
}
