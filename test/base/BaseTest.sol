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
import {PermitSingle} from "src/RePermit.sol";

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

    function signPermit(PermitSingle memory permit, uint256 privateKey) internal view returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IEIP712(Consts.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_SINGLE_TYPEHASH,
                        keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permit.details)),
                        permit.spender,
                        permit.sigDeadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    bytes32 private constant PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");
    bytes32 private constant PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );
}

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
