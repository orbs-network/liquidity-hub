// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {CosignatureLib} from "src/reactor/CosignatureLib.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {RePermit} from "src/repermit/RePermit.sol";

contract CosignatureLibTest is Test {
    RePermit rp;
    address signer;
    uint256 signerPK;
    address other;

    function setUp() public {
        rp = new RePermit();
        (signer, signerPK) = makeAddrAndKey("signer");
        other = makeAddr("other");
    }

    function callValidateCosignature(OrderLib.CosignedOrder memory co, bytes32 orderHash, address cosigner)
        external
        view
    {
        CosignatureLib.validate(co, orderHash, cosigner, address(rp));
    }

    function _signCosignature(OrderLib.Cosignature memory c) internal view returns (bytes memory sig) {
        bytes32 digest = rp.hashTypedData(OrderLib.hash(c));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function _baseCosignedWithSig() internal returns (OrderLib.CosignedOrder memory co, bytes32 orderHash) {
        OrderLib.Order memory o;
        o.info.swapper = signer;
        o.input.token = makeAddr("in");
        o.input.amount = 1_000;
        o.input.maxAmount = 2_000;
        o.output.token = makeAddr("out");
        o.output.amount = 500;
        o.output.maxAmount = 5_000;
        o.slippage = 100; // 1%

        orderHash = OrderLib.hash(o);
        co.order = o;

        OrderLib.Cosignature memory c;
        c.timestamp = block.timestamp;
        c.nonce = orderHash;
        c.input = OrderLib.CosignedValue({token: o.input.token, value: 100, decimals: 18});
        c.output = OrderLib.CosignedValue({token: o.output.token, value: 200, decimals: 18});
        co.cosignatureData = c;
        co.cosignature = _signCosignature(c);
    }

    function test_validateCosignature_ok() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_stale() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        vm.warp(block.timestamp + 1000);
        co.cosignatureData.timestamp = 0;
        vm.expectRevert(CosignatureLib.StaleCosignature.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_invalidNonce() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        co.cosignatureData.nonce = keccak256("other");
        vm.expectRevert(CosignatureLib.InvalidCosignatureNonce.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_invalidInputToken() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        co.cosignatureData.input.token = makeAddr("wrongIn");
        vm.expectRevert(CosignatureLib.InvalidCosignatureInputToken.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_invalidOutputToken() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        co.cosignatureData.output.token = makeAddr("wrongOut");
        vm.expectRevert(CosignatureLib.InvalidCosignatureOutputToken.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_zeroInputValue() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        co.cosignatureData.input.value = 0;
        vm.expectRevert(CosignatureLib.InvalidCosignatureZeroInputValue.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_zeroOutputValue() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        co.cosignatureData.output.value = 0;
        vm.expectRevert(CosignatureLib.InvalidCosignatureZeroOutputValue.selector);
        this.callValidateCosignature(co, orderHash, signer);
    }

    function test_validateCosignature_reverts_invalidCosigner() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();
        vm.expectRevert(CosignatureLib.InvalidCosignature.selector);
        this.callValidateCosignature(co, orderHash, other);
    }
}
