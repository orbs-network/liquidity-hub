// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, IMulticall3, Consts} from "src/LiquidityHub.sol";
import {RePermit, RePermitLib} from "src/RePermit.sol";

contract RePermitTest is BaseTest {
    RePermit public uut;

    address public signer;
    uint256 public signerPK;
    ERC20Mock public token;
    address public recipient;

    bytes32 public witness = keccak256(abi.encode("witness data verified by spender"));
    string public witnessTypeString = "bytes32 witness)";

    RePermitLib.RePermitTransferFrom public permit;
    RePermitLib.TransferRequest public request;

    function setUp() public override {
        super.setUp();
        uut = config.repermit;

        (signer, signerPK) = makeAddrAndKey("signer");
        token = new ERC20Mock();
        recipient = makeAddr("recipient");
    }

    function test_domainSeparator() public {
        assertNotEq(uut.DOMAIN_SEPARATOR().length, 0, "domain separator");
    }

    function test_nameAndVersion() public {
        (, string memory name, string memory version,,,,) = uut.eip712Domain();
        assertEq(name, "RePermit", "name");
        assertEq(version, "1", "version");
    }

    function test_revert_signatureExpired() public {
        permit.deadline = block.timestamp - 1;
        bytes memory signature = signRePermit();

        vm.expectRevert(RePermit.SignatureExpired.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_revert_invalidSignature() public {
        permit.deadline = block.timestamp;

        bytes memory signature = signRePermit();

        vm.expectRevert(RePermit.InvalidSignature.selector);
        uut.repermitWitnessTransferFrom(
            permit, request, signer, keccak256(abi.encode("other witness")), witnessTypeString, signature
        );
    }

    function test_revert_insufficientAllowance() public {
        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 1.1 ether;

        bytes memory signature = signRePermit();

        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0));
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_repermitWitnessTransferFrom_partialFill() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.7 ether;
        request.to = recipient;

        bytes memory signature = signRePermit();

        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);

        assertEq(token.balanceOf(signer), 0.3 ether, "signer balance");
        assertEq(token.balanceOf(recipient), 0.7 ether, "recipient balance");

        request.amount = 0.1 ether;
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);

        assertEq(token.balanceOf(signer), 0.2 ether, "signer balance");
        assertEq(token.balanceOf(recipient), 0.8 ether, "recipient balance");
    }

    function test_revert_insufficientAllowance_afterSpending() public {
        token.mint(signer, 1 ether);
        hoax(signer);
        token.approve(address(uut), 1 ether);

        permit.deadline = block.timestamp;
        permit.permitted.amount = 1 ether;
        permit.permitted.token = address(token);
        request.amount = 0.7 ether;
        request.to = recipient;

        bytes memory signature = signRePermit();

        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
        assertEq(token.balanceOf(recipient), 0.7 ether, "recipient balance");

        request.amount = 0.4 ether;
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0.7 ether));
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function test_cancel() public {
        permit.deadline = block.timestamp;
        bytes memory signature = signRePermit();
        hoax(signer);
        uut.cancel(permit.nonce);

        vm.expectRevert(RePermit.Canceled.selector);
        uut.repermitWitnessTransferFrom(permit, request, signer, witness, witnessTypeString, signature);
    }

    function signRePermit() private view returns (bytes memory signature) {
        bytes32 msgHash = ECDSA.toTypedDataHash(
            uut.DOMAIN_SEPARATOR(), RePermitLib.hashWithWitness(permit, witness, witnessTypeString, address(this))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, msgHash);
        signature = bytes.concat(r, s, bytes1(v));
    }
}
