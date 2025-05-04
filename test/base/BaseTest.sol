// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {
    ExclusiveDutchOrderLib,
    ExclusiveDutchOrder,
    DutchInput,
    DutchOutput
} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {BaseScript, Config} from "script/base/BaseScript.sol";
import {DeployTestInfra} from "./DeployTestInfra.sol";
import {Admin} from "src/Admin.sol";
import {
    LiquidityHub,
    IMulticall3,
    IReactor,
    IERC20,
    SignedOrder,
    IValidationCallback,
    IAllowed
} from "src/LiquidityHub.sol";
import {PartialOrderReactor, PartialOrderLib} from "src/PartialOrderReactor.sol";
import {RePermit} from "src/RePermit.sol";

abstract contract BaseTest is BaseScript, PermitSignature, DeployTestInfra {
    function setUp() public virtual override {
        // no call to super.setUp()
        initTestConfig();
    }

    function initTestConfig() public {
        address weth = deployTestInfra();

        Admin admin = new Admin(msg.sender);
        hoax(msg.sender);
        admin.init(weth);

        IReactor reactor = new ExclusiveDutchOrderReactor(IPermit2(Consts.PERMIT2_ADDRESS), address(0));
        IReactor reactor2 = new ExclusiveDutchOrderReactor(IPermit2(Consts.PERMIT2_ADDRESS), address(0));
        LiquidityHub executor = new LiquidityHub(reactor, IAllowed(address(admin)));

        RePermit repermit = new RePermit();
        PartialOrderReactor reactorPartial = new PartialOrderReactor(repermit);

        config = Config({
            admin: admin,
            executor: executor,
            reactor: reactor,
            reactor2: reactor2,
            reactorPartial: reactorPartial,
            repermit: repermit
        });
    }

    uint256 private nonce;
    address public ref = makeAddr("ref");
    uint8 public refshare = 90;
    uint8 public maxdecay = 50;

    function signedOrder(
        address signer,
        uint256 signerPK,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount,
        uint256 outAmountGas
    ) internal returns (SignedOrder memory result) {
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = signer;
            order.info.nonce = nonce++;
            order.info.deadline = block.timestamp + 2 minutes;
            order.decayStartTime = block.timestamp + 1 minutes;
            order.decayEndTime = order.info.deadline;

            order.exclusiveFiller = address(config.executor);
            order.info.additionalValidationContract = IValidationCallback(config.executor);
            order.info.additionalValidationData = abi.encode(ref, refshare);

            order.input.token = ERC20(inToken);
            order.input.startAmount = inAmount;
            order.input.endAmount = inAmount;

            order.outputs = new DutchOutput[](2);
            order.outputs[0] = DutchOutput(outToken, outAmount, outAmount * maxdecay / 100, signer);
            order.outputs[1] = DutchOutput(outToken, outAmountGas, outAmountGas, address(config.admin));
        }

        result.sig = signOrder(signerPK, PERMIT2_ADDRESS, order);
        result.order = abi.encode(order);
    }

    function signedPartialOrder(
        address signer,
        uint256 signerPK,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount,
        uint256 fillOutAmount
    ) internal view returns (SignedOrder memory result) {
        PartialOrderLib.PartialOrder memory order;
        {
            order.info.reactor = address(config.reactorPartial);
            order.info.swapper = signer;
            order.info.nonce = block.timestamp;
            order.info.deadline = block.timestamp + 10 minutes;

            order.exclusiveFiller = address(config.executor);
            // order.info.additionalValidationContract = IValidationCallback(config.executor); // this will work, but redundant and wastes gas

            order.input.token = inToken;
            order.input.amount = inAmount;

            order.outputs = new PartialOrderLib.PartialOutput[](1);
            order.outputs[0] = PartialOrderLib.PartialOutput(outToken, outAmount, signer);
        }

        result.sig = signRePermit(signerPK, order);
        result.order = abi.encode(PartialOrderLib.PartialFill(order, fillOutAmount));
    }
}
