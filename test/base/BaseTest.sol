// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {
    ExclusiveDutchOrderLib,
    ExclusiveDutchOrder,
    DutchInput,
    DutchOutput
} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

import {BaseScript, Config} from "script/base/BaseScript.sol";

import {
    LiquidityHub,
    Consts,
    IMulticall,
    IReactor,
    IERC20,
    SignedOrder,
    IValidationCallback,
    Call
} from "src/LiquidityHub.sol";
import {PartialOrderLib} from "src/PartialOrderReactor.sol";

abstract contract BaseTest is Base, PermitSignature, DeployTestInfra {

    function setUp() public virtual override {
        // no call to super.setUp()
        initTestConfig();
    }

    function initTestConfig() public {
        IReactor reactor = deployTestInfra();

        IWETH weth = IWETH(address(new WETH()));

        Admin admin = new Admin(weth, deployer);
        LiquidityHub executor = new LiquidityHub(reactor, admin);

        RePermit repermit = new RePermit();
        PartialOrderReactor reactorPartial = new PartialOrderReactor(repermit);

        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: executor,
            reactor: reactor,
            reactorPartial: reactorPartial,
            repermit: repermit,
            admin: admin,
            weth: weth
        });
    }

    function dealWETH(address target, uint256 amount) internal {
        hoax(target, amount);
        config.weth.deposit{value: amount}();
        assertEq(config.weth.balanceOf(target), amount, "weth balance");
    }

    function createAndSignOrder(
        address signer,
        uint256 signerPK,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount,
        uint256 outAmountGas
    ) internal view returns (SignedOrder memory result) {
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = signer;
            order.info.nonce = block.timestamp;
            order.info.deadline = block.timestamp + 10 minutes;
            order.decayStartTime = order.info.deadline;
            order.decayEndTime = order.info.deadline;

            order.exclusiveFiller = address(config.executor);
            order.info.additionalValidationContract = IValidationCallback(config.executor);

            order.input.token = ERC20(inToken);
            order.input.startAmount = inAmount;
            order.input.endAmount = inAmount;

            order.outputs = new DutchOutput[](2);
            order.outputs[0] = DutchOutput(outToken, outAmount, outAmount, signer);
            order.outputs[1] = DutchOutput(outToken, outAmountGas, outAmountGas, address(config.treasury));
        }

        result.sig = signOrder(signerPK, PERMIT2_ADDRESS, order);
        result.order = abi.encode(order);
    }

    function createAndSignPartialOrder(
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
            order.info.reactor = config.reactorPartial;
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

    function mockSwapCalls(ERC20Mock inToken, ERC20Mock outToken, uint256 inAmountMin, uint256 outAmountExact)
        internal
        view
        returns (Call[] memory calls)
    {
        calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), inAmountMin));
        calls[1] =
            Call(address(outToken), abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmountExact));
    }
}
