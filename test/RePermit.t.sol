// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock} from "test/base/BaseTest.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {SwapExecutor, SignedOrder, IMulticall3} from "src/executor/SwapExecutor.sol";
import {RePermit, RePermitLib} from "src/repermit/RePermit.sol";

contract RePermitTest is BaseTest {
    RePermit uut;

    bytes32 witness = keccak256(abi.encode("signed witness data verified by spender"));
    string witnessTypeString = "bytes32 witness)";

    RePermitLib.RePermitTransferFrom public permit;
    RePermitLib.TransferRequest public request;

    // Duplicate event for expectEmit
    event Spend(
        address indexed signer,
        bytes32 indexed permitHash,
        address indexed token,
        address to,
        uint256 amount,
        uint256 totalSpent
    );

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
        permit.nonce = 1234;

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
        vm.expectEmit(address(uut));
        emit RePermitLib.Cancel(signer, permit.nonce);

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

    function test_spend_event_emitted() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.25 ether;
        request.to = other;

        bytes32 structHash = hashRePermit(
            permit.permitted.token,
            permit.permitted.amount,
            permit.nonce,
            permit.deadline,
            witness,
            witnessTypeString,
            address(this)
        );
        bytes memory signature = signEIP712(repermit, signerPK, structHash);
        bytes32 digest = uut.hashTypedData(structHash);

        vm.expectEmit(address(uut));
        emit Spend(signer, digest, address(token), other, 0.25 ether, 0.25 ether);

        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_spender_binding_signature_replay_fails_for_other_spender() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.1 ether;
        request.to = other;

        // Sign for this contract as spender
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

        // Call from a different spender
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        vm.expectRevert(RePermit.InvalidSignature.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        vm.stopPrank();
    }

    function test_exact_allowance_exhaustion_then_reject_next_wei() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
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

        // Spend in two chunks that sum to exactly the allowance
        request.amount = 0.6 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        request.amount = 0.4 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);

        // Next wei should revert
        request.amount = 1;
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector));
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_new_permit_hash_independent_spent_tracking() public {
        token.mint(signer, 3 ether);
        hoax(signer);
        token.approve(address(uut), 3 ether);

        permit.deadline = block.timestamp;
        permit.permitted.token = address(token);
        request.to = other;

        // First permit with amount 1 ether
        permit.permitted.amount = 1 ether;
        bytes memory sig1 = signEIP712(
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
        request.amount = 0.7 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, sig1);

        // Second permit with different amount (different hash)
        permit.permitted.amount = 2 ether;
        bytes memory sig2 = signEIP712(
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
        request.amount = 1.5 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, sig2);

        // Both should succeed since spent maps to different hashes
        assertEq(token.balanceOf(other), 0.7 ether + 1.5 ether);
    }

    function test_hashTypedData_digest_matches_ECDSA() public {
        bytes32 structHash = keccak256("example-struct-hash");
        bytes32 expected = ECDSA.toTypedDataHash(uut.DOMAIN_SEPARATOR(), structHash);
        assertEq(uut.hashTypedData(structHash), expected, "digest");
    }

    function test_zero_amount_noop_does_not_increment_spent() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.to = other;
        request.amount = 0;

        bytes32 structHash = hashRePermit(
            permit.permitted.token,
            permit.permitted.amount,
            permit.nonce,
            permit.deadline,
            witness,
            witnessTypeString,
            address(this)
        );
        bytes memory signature = signEIP712(repermit, signerPK, structHash);
        bytes32 digest = uut.hashTypedData(structHash);

        uint256 beforeSpent = uut.spent(signer, digest);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        assertEq(uut.spent(signer, digest), beforeSpent, "spent unchanged for zero amount");
        assertEq(token.balanceOf(signer), 1 ether, "signer unchanged");
        assertEq(token.balanceOf(other), 0, "recipient unchanged");

        request.amount = 0.5 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        assertEq(uut.spent(signer, digest), beforeSpent + 0.5 ether, "spent increments");
        assertEq(token.balanceOf(signer), 0.5 ether, "signer debited");
        assertEq(token.balanceOf(other), 0.5 ether, "recipient credited");
    }

    function test_revert_invalidSignature_when_witnessType_suffix_mismatch() public {
        permit.deadline = block.timestamp;
        permit.permitted.token = address(token);
        permit.permitted.amount = 1 ether;
        request.amount = 0.1 ether;
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

        string memory otherSuffix = "bytes32 other)";
        vm.expectRevert(RePermit.InvalidSignature.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, otherSuffix, signature);
    }
}
