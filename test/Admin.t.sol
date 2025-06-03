// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, IMulticall3, ERC20Mock} from "test/base/BaseTest.sol";

import {Admin, IERC20, IWETH} from "src/Admin.sol";

contract AdminTest is BaseTest {
    Admin public uut;

    function setUp() public override {
        super.setUp();
        uut = Admin(payable(admin));
    }

    function test_owned() public {
        assertNotEq(uut.owner(), address(0));
        assertEq(uut.owner(), address(this));
    }

    function test_init() public {
        //init in setUp
        assertNotEq(address(uut.weth()), address(0));
    }

    function test_revert_owned() public {
        vm.expectRevert("Ownable: caller is not the owner");
        hoax(other);
        uut.init(address(0), address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        hoax(other);
        uut.allow(new address[](0), true);

        vm.expectRevert("Ownable: caller is not the owner");
        hoax(other);
        uut.execute(new IMulticall3.Call3[](0));

        vm.expectRevert("Ownable: caller is not the owner");
        hoax(other);
        uut.transfer(address(0), other);
    }

    function test_allowed() public {
        assertEq(uut.allowed(uut.owner()), true);
        assertEq(uut.allowed(address(0)), false);
        assertEq(uut.allowed(other), false);

        address[] memory addrs = new address[](1);
        addrs[0] = other;
        uut.allow(addrs, true);
        assertEq(uut.allowed(other), true);
    }

    function test_transfer() public {
        token.mint(address(uut), 1 ether);
        assertEq(token.balanceOf(other), 0);
        uut.transfer(address(token), other);
        assertEq(token.balanceOf(other), 1 ether);
    }

    function test_transfer_native() public {
        deal(address(uut), 1 ether);
        address recipient = other;
        assertEq(recipient.balance, 0);

        uut.transfer(address(0), recipient);
        assertEq(recipient.balance, 1 ether);
    }

    function test_weth() public {
        assertEq(IWETH(weth).balanceOf(address(uut)), 0);

        hoax(address(uut), 1 ether);
        IWETH(weth).deposit{value: 1 ether}();
        assertEq(IWETH(weth).balanceOf(address(uut)), 1 ether);

        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](1);
        calls[0] = IMulticall3.Call3({
            target: address(weth),
            callData: abi.encodeWithSelector(IWETH.withdraw.selector, 1 ether),
            allowFailure: false
        });
        uut.execute(calls);
        assertEq(IWETH(weth).balanceOf(address(uut)), 0);
        assertEq(address(uut).balance, 1 ether);

        uut.transfer(address(0), other);
        assertEq(other.balance, 1 ether);
        assertEq(address(uut).balance, 0);
    }
}
