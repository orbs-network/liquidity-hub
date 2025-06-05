// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, IMulticall3} from "src/executor/LiquidityHub.sol";
import {RePermit, RePermitLib} from "src/repermit/RePermit.sol";

contract RePermitTest is BaseTest {
    RePermit uut;

    bytes32 witness = keccak256(abi.encode("signed witness data verified by spender"));
    string witnessTypeString = "bytes32 witness)";

    RePermitLib.RePermitTransferFrom public permit;
    RePermitLib.TransferRequest public request;

    function setUp() public override {
        super.setUp();
        uut = RePermit(address(repermit));
    }

    function test_meta() public {
        assertNotEq(uut.DOMAIN_SEPARATOR().length, 0, "domain separator");
        (, string memory name, string memory version,,,,) = uut.eip712Domain();
        assertEq(name, "RePermit", "name");
        assertEq(version, "1", "version");
    }

    function test_revert_expired() public {
        permit.deadline = block.timestamp - 1;
        bytes memory signature = signEIP712(repermit, signerPK, witness);

        vm.expectRevert(RePermit.Expired.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_revert_invalidSignature() public {
        permit.deadline = block.timestamp;
        bytes memory signature = signEIP712(repermit, signerPK, witness);

        vm.expectRevert(RePermit.InvalidSignature.selector);
        uut.repermitWitnessTransferFrom(
            permit, request, signer, keccak256(abi.encode("other witness")), witnessTypeString, signature
        );
    }

    function test_revert_insufficientAllowance() public {
        permit.deadline = block.timestamp;
        permit.permitted.token = address(token);
        permit.permitted.amount = 1 ether;
        request.amount = 1.1 ether;

        bytes memory signature = signEIP712(
            repermit,
            signerPK,
            hashRePermit(
                permit.permitted.token,
                permit.permitted.amount,
                permit.nonce,
                permit.deadline,
                witness,
                witnessTypeString,
                address(this)
            )
        );

        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector));
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_revert_insufficientAllowance_afterSpending() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.7 ether;
        request.to = other;

        bytes memory signature = signEIP712(
            repermit,
            signerPK,
            hashRePermit(
                permit.permitted.token,
                permit.permitted.amount,
                permit.nonce,
                permit.deadline,
                witness,
                witnessTypeString,
                address(this)
            )
        );

        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        assertEq(token.balanceOf(other), 0.7 ether, "recipient balance");

        request.amount = 0.5 ether;
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector));
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_cancel() public {
        permit.deadline = block.timestamp;

        bytes memory signature = signEIP712(
            repermit,
            signerPK,
            hashRePermit(
                permit.permitted.token,
                permit.permitted.amount,
                permit.nonce,
                permit.deadline,
                witness,
                witnessTypeString,
                address(this)
            )
        );
        hoax(signer);
        uut.cancel(permit.nonce);

        vm.expectRevert(RePermit.Canceled.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_fill() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.7 ether;
        request.to = other;

        bytes memory signature = signEIP712(
            repermit,
            signerPK,
            hashRePermit(
                permit.permitted.token,
                permit.permitted.amount,
                permit.nonce,
                permit.deadline,
                witness,
                witnessTypeString,
                address(this)
            )
        );
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);

        assertEq(token.balanceOf(signer), 0.3 ether, "signer balance");
        assertEq(token.balanceOf(other), 0.7 ether, "recipient balance");

        request.amount = 0.1 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);

        assertEq(token.balanceOf(signer), 0.2 ether, "signer balance");
        assertEq(token.balanceOf(other), 0.8 ether, "recipient balance");
    }
}
