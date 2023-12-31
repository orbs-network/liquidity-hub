// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH} from "test/base/BaseTest.sol";

import {PartialFillReactor, SignedOrder, Call} from "src/PartialFillReactor.sol";

contract PartialFillReactorTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    function setUp() public override {
        super.setUp();
        vm.etch(address(config.reactor), address(new PartialFillReactor()).code);
        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        inToken.mint(swapper, 10 ether);
        hoax(swapper);
        inToken.approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function test_Execute_SwapTheFullAmount() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.1 ether;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, outAmountGas
        );
        //simulate swap
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), inAmount));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(outToken.balanceOf(swapper), outAmount, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), outAmountGas, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
    }
}
