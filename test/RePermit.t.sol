// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract RePermitTest is BaseTest {
    address public owner;
    uint256 public ownerPK;

    address public spender;

    ERC20Mock public token;
    uint256 public totalAmount = 10 ether;

    function setUp() public override {
        super.setUp();
        (owner, ownerPK) = makeAddrAndKey("owner");
        spender = makeAddr("spender");
        token = new ERC20Mock();
    }

    function test_Revert_NotApproved() public {
        //
    }
}
