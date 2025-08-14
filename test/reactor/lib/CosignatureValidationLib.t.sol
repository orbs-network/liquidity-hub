// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BaseTest} from "test/base/BaseTest.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {RePermit} from "src/repermit/RePermit.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {CosignatureValidationLib} from "src/reactor/CosignatureValidationLib.sol";

contract CosignatureValidationHarness {
    function callValidate(OrderLib.CosignedOrder memory cosigned, bytes32 orderHash, address cosigner, address permit2)
        external
        view
    {
        CosignatureValidationLib.validateCosignature(cosigned, orderHash, cosigner, permit2);
    }
}

contract CosignatureValidationLibTest is BaseTest {
    CosignatureValidationHarness harness;
    RePermit rp;

    function setUp() public override {
        super.setUp();
        harness = new CosignatureValidationHarness();
        rp = RePermit(repermit);
    }

    function buildOrder() internal view returns (OrderLib.Order memory o) {
        o.info.swapper = signer;
        o.input.token = address(token);
        o.input.amount = 1000;
        o.input.maxAmount = 2000;
        o.output.token = address(token);
        o.output.amount = 500;
        o.output.maxAmount = 5_000;
        o.slippage = 100; // 1%
    }

    function signCosignature(OrderLib.Cosignature memory c) internal view returns (bytes memory sig) {
        bytes32 digest = rp.hashTypedData(OrderLib.hash(c));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function baseCosigned() internal view returns (OrderLib.CosignedOrder memory co, bytes32 orderHash) {
        OrderLib.Order memory o = buildOrder();
        orderHash = OrderLib.hash(o);
        co.order = o;

        OrderLib.Cosignature memory c;
        c.timestamp = block.timestamp;
        c.nonce = orderHash;
        c.input = OrderLib.CosignedValue({token: o.input.token, value: 100, decimals: 18});
        c.output = OrderLib.CosignedValue({token: o.output.token, value: 200, decimals: 18});
        co.cosignatureData = c;
        co.cosignature = signCosignature(c);
    }

    function test_validate_ok() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        harness.callValidate(co, orderHash, signer, repermit);
    }

    function test_revert_stale() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        // Advance time to ensure 0 + freshness < now
        vm.warp(block.timestamp + 1000);
        // Simulate clearly stale timestamp (0 + freshness < now)
        co.cosignatureData.timestamp = 0;
        vm.expectRevert(CosignatureValidationLib.StaleCosignature.selector);
        harness.callValidate(co, orderHash, signer, repermit);
    }

    function test_revert_nonce_mismatch() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        co.cosignatureData.nonce = keccak256("other");
        vm.expectRevert(CosignatureValidationLib.InvalidCosignatureNonce.selector);
        harness.callValidate(co, orderHash, signer, repermit);
    }

    function test_revert_input_token_mismatch() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        co.cosignatureData.input.token = address(0xBEEF);
        vm.expectRevert(CosignatureValidationLib.InvalidCosignatureInputToken.selector);
        harness.callValidate(co, orderHash, signer, repermit);
    }

    function test_revert_zero_values() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        co.cosignatureData.input.value = 0;
        vm.expectRevert(CosignatureValidationLib.InvalidCosignatureZeroInputValue.selector);
        harness.callValidate(co, orderHash, signer, repermit);
        // rebuild fresh cosigned
        (co, orderHash) = baseCosigned();
        co.cosignatureData.output.value = 0;
        vm.expectRevert(CosignatureValidationLib.InvalidCosignatureZeroOutputValue.selector);
        harness.callValidate(co, orderHash, signer, repermit);
    }

    function test_revert_invalid_signature_wrong_cosigner() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = baseCosigned();
        address wrong = other; // signature is from signer, not other
        vm.expectRevert(CosignatureValidationLib.InvalidCosignature.selector);
        harness.callValidate(co, orderHash, wrong, repermit);
    }
}
