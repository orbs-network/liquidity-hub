// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {ReactorLib} from "src/reactor/ReactorLib.sol";
import {OrderLib} from "src/reactor/OrderLib.sol";
import {RePermit} from "src/repermit/RePermit.sol";

contract ReactorLibTest is Test {
    // Epoch storage for testing
    mapping(bytes32 => uint256) internal epochs;

    // Common test state
    RePermit rp;
    address signer;
    uint256 signerPK;
    address other;

    function setUp() public {
        rp = new RePermit();
        (signer, signerPK) = makeAddrAndKey("signer");
        other = makeAddr("other");
    }

    // Inline wrappers to create external call depth for expectRevert
    function callValidateOrder(OrderLib.Order memory order) external pure {
        ReactorLib.validateOrder(order);
    }

    function callResolve(OrderLib.CosignedOrder memory co) external pure returns (uint256) {
        return ReactorLib.resolveOutAmount(co);
    }

    function callEpoch(bytes32 h, uint256 interval) external {
        ReactorLib.validateAndUpdate(epochs, h, interval);
    }

    function callValidateCosignature(OrderLib.CosignedOrder memory co, bytes32 orderHash, address cosigner)
        external
        view
    {
        ReactorLib.validateCosignature(co, orderHash, cosigner, address(rp));
    }

    // ---------- Order validation ----------
    function _baseOrder() internal returns (OrderLib.Order memory o) {
        o.info.swapper = signer;
        o.input.token = makeAddr("token");
        o.input.amount = 100;
        o.input.maxAmount = 200;
        o.output.token = makeAddr("tokenOut");
        o.output.amount = 50;
        o.output.maxAmount = 100;
        o.output.recipient = other;
        o.slippage = 100; // 1%
    }

    function test_validateOrder_ok() public {
        OrderLib.Order memory o = _baseOrder();
        this.callValidateOrder(o);
    }

    function test_validateOrder_reverts() public {
        OrderLib.Order memory o;

        o = _baseOrder();
        o.input.amount = 0;
        vm.expectRevert(ReactorLib.InvalidOrderInputAmountZero.selector);
        this.callValidateOrder(o);

        o = _baseOrder();
        o.input.amount = o.input.maxAmount + 1;
        vm.expectRevert(ReactorLib.InvalidOrderInputAmountGtMax.selector);
        this.callValidateOrder(o);

        o = _baseOrder();
        o.output.amount = o.output.maxAmount + 1;
        vm.expectRevert(ReactorLib.InvalidOrderOutputAmountGtMax.selector);
        this.callValidateOrder(o);

        o = _baseOrder();
        o.slippage = ReactorLib.MAX_SLIPPAGE; // >= MAX_SLIPPAGE
        vm.expectRevert(ReactorLib.InvalidOrderSlippageTooHigh.selector);
        this.callValidateOrder(o);

        o = _baseOrder();
        o.input.token = address(0);
        vm.expectRevert(ReactorLib.InvalidOrderInputTokenZero.selector);
        this.callValidateOrder(o);

        o = _baseOrder();
        o.output.recipient = address(0);
        vm.expectRevert(ReactorLib.InvalidOrderOutputRecipientZero.selector);
        this.callValidateOrder(o);
    }

    // ---------- Resolution ----------
    function _baseCosigned() internal returns (OrderLib.CosignedOrder memory co) {
        OrderLib.Order memory o;
        o.info.swapper = signer;
        o.input.token = makeAddr("in");
        o.input.amount = 1_000; // chunk
        o.input.maxAmount = 2_000;
        o.output.token = makeAddr("out");
        o.output.amount = 1_200; // limit
        o.output.maxAmount = 10_000; // trigger
        o.slippage = 100; // 1%

        co.order = o;
        co.cosignatureData.input = OrderLib.CosignedValue({token: o.input.token, value: 100, decimals: 18});
        co.cosignatureData.output = OrderLib.CosignedValue({token: o.output.token, value: 200, decimals: 18});
    }

    function test_resolveOutAmount_ok() public {
        OrderLib.CosignedOrder memory co = _baseCosigned();
        uint256 outAmt = this.callResolve(co);
        assertEq(outAmt, 1_980); // see math in previous tests
    }

    function test_resolveOutAmount_revert_cosigned_exceeds_max() public {
        OrderLib.CosignedOrder memory co = _baseCosigned();
        co.order.output.maxAmount = 1_500; // cosignedOutput is 2000 > 1500
        vm.expectRevert(ReactorLib.CosignedMaxAmount.selector);
        this.callResolve(co);
    }

    // ---------- Epoch ----------
    function test_epoch_zero_allows_once() public {
        bytes32 h = keccak256("h");
        this.callEpoch(h, 0);
        vm.expectRevert(ReactorLib.InvalidEpoch.selector);
        this.callEpoch(h, 0);
    }

    function test_epoch_interval_progression() public {
        bytes32 h = keccak256("h");
        uint256 interval = 60;
        this.callEpoch(h, interval);
        vm.expectRevert(ReactorLib.InvalidEpoch.selector);
        this.callEpoch(h, interval);
        vm.warp(block.timestamp + interval);
        this.callEpoch(h, interval);
    }

    // ---------- Cosignature ----------
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

    function test_validateCosignature_reverts() public {
        (OrderLib.CosignedOrder memory co, bytes32 orderHash) = _baseCosignedWithSig();

        // stale
        vm.warp(block.timestamp + 1000);
        co.cosignatureData.timestamp = 0;
        vm.expectRevert(ReactorLib.StaleCosignature.selector);
        this.callValidateCosignature(co, orderHash, signer);

        // reset
        (co, orderHash) = _baseCosignedWithSig();
        co.cosignatureData.nonce = keccak256("other");
        vm.expectRevert(ReactorLib.InvalidCosignatureNonce.selector);
        this.callValidateCosignature(co, orderHash, signer);

        (co, orderHash) = _baseCosignedWithSig();
        co.cosignatureData.input.token = makeAddr("wrongIn");
        vm.expectRevert(ReactorLib.InvalidCosignatureInputToken.selector);
        this.callValidateCosignature(co, orderHash, signer);

        (co, orderHash) = _baseCosignedWithSig();
        co.cosignatureData.input.value = 0;
        vm.expectRevert(ReactorLib.InvalidCosignatureZeroInputValue.selector);
        this.callValidateCosignature(co, orderHash, signer);

        (co, orderHash) = _baseCosignedWithSig();
        co.cosignatureData.output.value = 0;
        vm.expectRevert(ReactorLib.InvalidCosignatureZeroOutputValue.selector);
        this.callValidateCosignature(co, orderHash, signer);

        (co, orderHash) = _baseCosignedWithSig();
        vm.expectRevert(ReactorLib.InvalidCosignature.selector);
        this.callValidateCosignature(co, orderHash, other);
    }
}
