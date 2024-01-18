// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH, SignedOrder} from "test/base/BaseTest.sol";

import {PartialOrderReactor, RePermit, Call} from "src/PartialOrderReactor.sol";

contract PartialOrderReactorTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    RePermit public repermit;

    function setUp() public override {
        super.setUp();
        repermit = new RePermit();
        vm.etch(address(config.reactor), address(new PartialOrderReactor(repermit)).code);

        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        inToken.mint(swapper, 10 ether);
        hoax(swapper);
        inToken.approve(address(repermit), type(uint256).max);
    }

    function test_Execute_SwapTheFullAmount() public {
        uint256 orderAmount = 1 ether;
        uint256 paritalOrderAmount = orderAmount;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.1 ether;

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            paritalOrderAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), paritalOrderAmount));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.1 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
    }

    function test_Execute_SwapTwice() public {
        uint256 orderAmount = 1 ether;
        uint256 partialAmount = 0.5 ether; // 100%
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.1 ether;

        SignedOrder[] memory orders1 = new SignedOrder[](1);
        orders1[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls1 = new Call[](2);
        calls1[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls1[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders1, calls1);

        assertEq(outToken.balanceOf(swapper), 0.25 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.05 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");


        SignedOrder[] memory orders2 = new SignedOrder[](1);
        orders2[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls2= new Call[](2);
        calls2[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls2[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders2, calls2);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.1 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
    }

    function test_Execute_SwapTheHalfAmount() public {
        uint256 orderAmount = 1 ether;
        uint256 partialAmount = 0.4 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;


        //assertEq(inToken.balanceOf(swapper), orderAmount, "Swapper should have this amount of inToken");

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(outToken.balanceOf(swapper),  0.2 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.028 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
    }


    function test_Execute_SwapTheDoubleAmount() public {
        uint256 orderAmount = 1 ether;
        uint256 partialAmount = 1.01 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;


        //assertEq(inToken.balanceOf(swapper), orderAmount, "Swapper should have this amount of inToken");

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, address(0)));
        config.executor.execute(orders, calls);

    }


    function test_Execute_SwapTwiceTheInsufficientAmount() public {
        uint256 orderAmount = 1 ether;
        uint256 partialAmount = 0.75 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;


        //assertEq(inToken.balanceOf(swapper), orderAmount, "Swapper should have this amount of inToken");

        SignedOrder[] memory orders1 = new SignedOrder[](1);
        orders1[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls1 = new Call[](2);
        calls1[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls1[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders1, calls1);

        SignedOrder[] memory orders2 = new SignedOrder[](1);
        orders2[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            orderAmount,
            partialAmount,
            outAmount,
            outAmountGas
        );
        //simulate swap
        Call[] memory calls2 = new Call[](2);
        calls2[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), partialAmount));
        calls2[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, address(0.75 ether)));
        config.executor.execute(orders2, calls2);
    }

}
