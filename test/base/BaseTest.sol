// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";

import {BaseScript} from "script/base/BaseScript.sol";
import {DeployTestInfra} from "./DeployTestInfra.sol";

import {Admin} from "src/Admin.sol";
import {RePermit} from "src/repermit/RePermit.sol";

abstract contract BaseTest is BaseScript, PermitSignature, DeployTestInfra {
    address multicall;
    address weth;
    address permit2;

    address admin;
    address repermit;

    ERC20Mock token;

    function setUp() public virtual override {
        super.setUp();
        (permit2, multicall, weth) = deployTestInfra();

        admin = address(new Admin(address(this)));
        Admin(payable(admin)).init(multicall, weth);
        vm.label(admin, "admin");

        repermit = address(new RePermit());
        vm.label(repermit, "repermit");

        token = new ERC20Mock();
        vm.label(address(token), "token");
    }

    // uint256 private nonce;
    // address public ref = makeAddr("ref");
    // uint8 public refshare = 90;
    //
    // function signedOrder(
    //     address signer,
    //     uint256 signerPK,
    //     address inToken,
    //     address outToken,
    //     uint256 inAmount,
    //     uint256 outAmount,
    //     uint256 outAmountGas
    // ) internal returns (SignedOrder memory result) {
    //     ExclusiveDutchOrder memory order;
    //     {
    //         order.info.reactor = config.reactor;
    //         order.info.swapper = signer;
    //         order.info.nonce = nonce++;
    //         order.info.deadline = block.timestamp + 2 minutes;
    //         order.decayStartTime = block.timestamp + 1 minutes;
    //         order.decayEndTime = order.info.deadline;
    //
    //         order.exclusiveFiller = address(config.executor);
    //         order.info.additionalValidationContract = IValidationCallback(config.executor);
    //         order.info.additionalValidationData = abi.encode(ref, refshare);
    //
    //         order.input.token = ERC20(inToken);
    //         order.input.startAmount = inAmount;
    //         order.input.endAmount = inAmount;
    //
    //         order.outputs = new DutchOutput[](2);
    //         order.outputs[0] = DutchOutput(outToken, outAmount, outAmount * maxdecay / 100, signer);
    //         order.outputs[1] = DutchOutput(outToken, outAmountGas, outAmountGas, address(config.admin));
    //     }
    //
    //     result.sig = signOrder(signerPK, PERMIT2_ADDRESS, order);
    //     result.order = abi.encode(order);
    // }
    //
    // function signedPartialOrder(
    //     address signer,
    //     uint256 signerPK,
    //     address inToken,
    //     address outToken,
    //     uint256 inAmount,
    //     uint256 outAmount,
    //     uint256 fillOutAmount
    // ) internal view returns (SignedOrder memory result) {
    //     PartialOrderLib.PartialOrder memory order;
    //     {
    //         order.info.reactor = address(config.reactorPartial);
    //         order.info.swapper = signer;
    //         order.info.nonce = block.timestamp;
    //         order.info.deadline = block.timestamp + 10 minutes;
    //
    //         order.exclusiveFiller = address(config.executor);
    //         // order.info.additionalValidationContract = IValidationCallback(config.executor); // this will work, but redundant and wastes gas
    //
    //         order.input.token = inToken;
    //         order.input.amount = inAmount;
    //
    //         order.outputs = new PartialOrderLib.PartialOutput[](1);
    //         order.outputs[0] = PartialOrderLib.PartialOutput(outToken, outAmount, signer);
    //     }
    //
    //     result.sig = signRePermit(signerPK, order);
    //     result.order = abi.encode(PartialOrderLib.PartialFill(order, fillOutAmount));
    // }
}
