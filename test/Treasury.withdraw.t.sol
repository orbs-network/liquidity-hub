// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/BaseTest.sol";

import {Treasury} from "src/Treasury.sol";

contract TreasuryWithdrawTest is BaseTest {
    address owner;

    function setUp() public withMockConfig {
        owner = config.treasury.owner();
    }

    function test_Empty() public {
        hoax(owner, 0);
        config.treasury.withdraw();
        assertEq(owner.balance, 0);
    }

    function test_ETH() public {
        deal(address(config.treasury), 1 ether);
        hoax(owner, 0);
        config.treasury.withdraw();
        assertEq(owner.balance, 1 ether);
    }

    function test_WETH() public {
        dealWETH(address(config.treasury), 1 ether);
        hoax(owner, 0);
        config.treasury.withdraw();
        assertEq(owner.balance, 1 ether);
    }

    function test_Tokens() public {
        ERC20Mock token = new ERC20Mock();
        token.mint(address(config.treasury), 1 ether);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = token;

        hoax(owner, 0);
        config.treasury.withdraw(tokens);
        assertEq(token.balanceOf(owner), 1 ether);
    }
}
