// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, Call} from "src/LiquidityHub.sol";

contract LiquidityHubForkTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;

    function setUp() public override {
        super.setUp();
        (swapper, swapperPK) = makeAddrAndKey("swapper");
    }

    function testFork_Paraswap() public {
        IWETH inToken = config.weth;
        address outToken = address(0);
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        hoax(swapper, 0);
        inToken.approve(PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createOrder(swapper, swapperPK, address(inToken), inAmount, address(outToken), outAmount);

        Call[] memory calls = new Call[](1);
        calls[0].target = address(inToken);
        calls[0].callData = abi.encodeWithSelector(IWETH.withdraw.selector, inAmount);

        dealWETH(swapper, inAmount);
        hoax(config.treasury.owner());
        config.executor.execute(orders, calls, new address[](0));

        assertEq(swapper.balance, outAmount);
        assertEq(address(config.executor).balance, 0);
        assertEq(address(config.treasury).balance, inAmount - outAmount);
    }
}
