// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {Admin, IERC20} from "src/Admin.sol";

contract AdminAccessTest is BaseTest {
    Admin public uut;

    function setUp() public override {
        super.setUp();
        uut = Admin(payable(admin));
    }

    function test_owned() public {
        assertNotEq(uut.owner(), address(0));
    }

    function test_init() public {
        //init in setUp
        assertNotEq(address(uut.weth()), address(0));
    }

    function test_revert_admin_init() public {
        vm.expectRevert("Ownable: caller is not the owner");
        hoax(address(1));
        uut.init(address(0), address(0));
    }

    function test_allowed() public {
        assertEq(uut.allowed(uut.owner()), true);
        assertEq(uut.allowed(address(0)), false);
        assertEq(uut.allowed(address(1)), false);
    }

    function test_allow_onlyOwner() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(1);
        uut.allow(addrs, true);
        assertEq(uut.allowed(address(1)), true);
    }

    function test_revert_allow_onlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        hoax(address(1));
        uut.allow(new address[](0), true);
    }

    function test_revert_transfer_onlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        hoax(address(1));
        uut.transfer(address(0), address(1));
    }

    function test_transfer() public {
        token.mint(address(uut), 1 ether);
        assertEq(IERC20(address(token)).balanceOf(address(1)), 0);
        uut.transfer(address(token), address(1));
        assertEq(IERC20(address(token)).balanceOf(address(1)), 1 ether);
    }
}
