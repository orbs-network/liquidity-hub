// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";

import {Base, Config, RFQ, Order} from "script/base/Base.sol";

import {LiquidityHub, IMulticall, IReactor, IERC20, SignedOrder} from "src/LiquidityHub.sol";
import {Treasury, IWETH} from "src/Treasury.sol";

abstract contract BaseTest is Base, PermitSignature {
    function setUp() public virtual override {
        // no call to super.setUp()
        initTestConfig();
    }

    function dealWETH(address target, uint256 amount) internal {
        hoax(target, amount);
        config.weth.deposit{value: amount}();
        assertEq(config.weth.balanceOf(target), amount);
    }

    function createAndSignOrder(
        address swapper,
        uint256 privateKey,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    ) internal view returns (SignedOrder memory result) {
        Order memory order = createOrder(RFQ(swapper, inToken, outToken, inAmount, outAmount));
        result.sig = signOrder(privateKey, PERMIT2_ADDRESS, order.order);
        result.order = order.encoded;
    }
}
