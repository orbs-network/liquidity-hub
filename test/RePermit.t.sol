// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call, Consts} from "src/LiquidityHub.sol";
import {RePermit, RePermitLib} from "src/RePermit.sol";

contract RePermitTest is BaseTest {
    RePermit public uut;

    function setUp() public override {
        super.setUp();
        uut = config.repermit;
    }

    function test_domainSeparator() public {
        assertNotEq(uut.DOMAIN_SEPARATOR().length, 0, "domain separator");
    }

    function test_nameAndVersion() public {
        (,string memory name, string memory version,,,,) = uut.eip712Domain();
        assertEq(name, "RePermit", "name");
        assertEq(version, "1", "version");
    }
    
    function test_revert_signatureExpired() public {
        RePermitLib.RePermitTransferFrom memory permit =
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(makeAddr("token"), 1 ether),
                0,
                block.timestamp - 1
            );

        // vm.expectRevert();
        // uut.repermitWitnessTransferFrom(permit, request, owner, witness, witnessTypeString, signature);
    }
    
    function test_revert_invalidSignature() public {
        RePermitLib.RePermitTransferFrom memory permit =
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(makeAddr("token"), 1 ether),
                0,
                block.timestamp + 1
            );

        // vm.expectRevert();
        // uut.repermitWitnessTransferFrom(permit, request, owner, witness, witnessTypeString, signature);
    }

    function test_revert_insufficientAllowance() public {
        RePermitLib.RePermitTransferFrom memory permit =
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(makeAddr("token"), 1 ether),
                0,
                block.timestamp + 1
            );

        // vm.expectRevert();
        // uut.repermitWitnessTransferFrom(permit, request, owner, witness, witnessTypeString, signature);
    }

    function test_repermitWitnessTransferFrom() public {
        RePermitLib.RePermitTransferFrom memory permit =
            RePermitLib.RePermitTransferFrom(
                RePermitLib.TokenPermissions(makeAddr("token"), 1 ether),
                0,
                block.timestamp + 1
            );
        // RePermitLib.TransferRequest memory request = RePermitLib.TransferRequest(owner, 1 ether);

        // uut.repermitWitnessTransferFrom(permit, request, owner, witness, witnessTypeString, signature);
    }
}
