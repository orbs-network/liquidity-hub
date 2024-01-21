// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {
    ExclusiveDutchOrderLib,
    ExclusiveDutchOrder,
    DutchInput,
    DutchOutput
} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";

import {Base, Config} from "script/base/Base.sol";

import {
    LiquidityHub, Consts, IMulticall, IReactor, IERC20, SignedOrder, IValidationCallback
} from "src/LiquidityHub.sol";
import {Treasury, IWETH} from "src/Treasury.sol";
import {PartialOrderLib} from "src/PartialOrderReactor.sol";

abstract contract BaseTest is Base, PermitSignature {
    function setUp() public virtual override {
        // no call to super.setUp()
        initTestConfig();
    }

    function dealWETH(address target, uint256 amount) internal {
        hoax(target, amount);
        config.weth.deposit{value: amount}();
        assertEq(config.weth.balanceOf(target), amount, "weth balance");
    }

    function createAndSignOrder(
        address swapper,
        uint256 privateKey,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount,
        uint256 outAmountGas
    ) internal view returns (SignedOrder memory result) {
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = swapper;
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
            order.outputs[0] = DutchOutput(outToken, outAmount, outAmount, swapper);
            order.outputs[1] = DutchOutput(outToken, outAmountGas, outAmountGas, address(config.treasury));
        }

        result.sig = signOrder(privateKey, PERMIT2_ADDRESS, order);
        result.order = abi.encode(order);
    }

    function createAndSignPartialOrder(
        address swapper,
        uint256 privateKey,
        address inToken,
        address outToken,
        uint256 orderAmount,
        uint256 partialOrderAmount,
        uint256 outAmount,
        uint256 outAmountGas
    ) internal view returns (SignedOrder memory result) {
        PartialOrderLib.PartialOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = swapper;
            order.info.nonce = block.timestamp;
            order.info.deadline = block.timestamp + 10 minutes;

            order.exclusiveFiller = address(config.executor);

            order.input.token = inToken;
            order.input.amount = orderAmount;

            order.outputs = new PartialOrderLib.PartialOutput[](2);
            order.outputs[0] = PartialOrderLib.PartialOutput(outToken, outAmount, swapper);
            order.outputs[1] = PartialOrderLib.PartialOutput(outToken, outAmountGas, address(config.treasury));
        }

        result.sig = signRePermit(privateKey, order);
        result.order = abi.encode(order, partialOrderAmount);
    }
}
