// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call, Consts} from "src/LiquidityHub.sol";
import {RePermit, PermitSingle, PermitDetails} from "src/RePermit.sol";

contract RePermitTest is BaseTest {
    RePermit public uut;

    address public owner;
    uint256 public ownerPK;

    address public spender;

    ERC20Mock public token;
    uint256 public totalAmount = 10 ether;
    uint40 public deadline = uint40(block.timestamp + 100);

    function setUp() public override {
        super.setUp();
        uut = RePermit(Consts.PERMIT2_ADDRESS);

        (owner, ownerPK) = makeAddrAndKey("owner");
        spender = makeAddr("spender");
        token = new ERC20Mock();

        token.mint(owner, totalAmount * 2);
        hoax(owner);
        token.approve(Consts.PERMIT2_ADDRESS, type(uint256).max);
    }

    function test_Permit_Transfer() public {
        PermitSingle memory permit =
            PermitSingle(PermitDetails(address(token), uint160(totalAmount), deadline, 0), spender, deadline);
        bytes memory sig = signPermit(permit, ownerPK);
        uut.permit(owner, permit, sig);

        address target = makeAddr("target");

        hoax(spender);
        uut.transferFrom(owner, target, uint160(totalAmount / 2), address(token));
        hoax(spender);
        uut.transferFrom(owner, target, uint160(totalAmount / 2), address(token));
        assertEq(token.balanceOf(target), totalAmount, "target end balance");
    }

    function test_Revert_InvalidSignature() public {
        PermitSingle memory permit =
            PermitSingle(PermitDetails(address(token), uint160(totalAmount), deadline, 0), spender, deadline);
        bytes memory sig = signPermit(permit, 0x1234);

        vm.expectRevert();
        uut.permit(owner, permit, sig);
    }

    function test_Revert_Deadline() public {
        PermitSingle memory permit =
            PermitSingle(PermitDetails(address(token), uint160(totalAmount), deadline, 0), spender, block.timestamp - 1);
        bytes memory sig = signPermit(permit, ownerPK);

        vm.expectRevert();
        uut.permit(owner, permit, sig);
    }
}
