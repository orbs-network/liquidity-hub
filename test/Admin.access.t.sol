// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {Admin, IERC20} from "src/Admin.sol";

contract AdminAccessTest is BaseTest {
    function test_Owned() public {
        assertNotEq(config.admin.owner(), address(0));
    }

    function test_Admin_init() public {
        assertNotEq(address(config.admin.weth()), address(0));
    }
    
    function test_Revert_Admin_init() public {
        vm.expectRevert("Ownable: caller is not the owner");
        config.admin.init(address(0));
    }

    function test_Allowed() public {
        assertEq(config.admin.allowed(config.admin.owner()), true);
        assertEq(config.admin.allowed(address(0)), false);
        assertEq(config.admin.allowed(address(1)), false);
    }

    function test_Allow_OnlyOwner() public {
        hoax(config.admin.owner());
        address[] memory addrs = new address[](1);
        addrs[0] = address(1);
        config.admin.allow(addrs, true);
        assertEq(config.admin.allowed(address(1)), true);
    }

    function test_Revert_Allow_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        config.admin.allow(new address[](0), true);
    }

    function test_Withdraw_OnlyAllowed() public {
        hoax(config.admin.owner());
        config.admin.withdraw(new IERC20[](0));
    }

    function test_Revert_Withdraw_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        config.admin.withdraw(new IERC20[](0));
    }
}
