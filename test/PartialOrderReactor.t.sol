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
    uint256 public inTokenTotalSupply = 10 ether;

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

        inToken.mint(swapper, inTokenTotalSupply);
        hoax(swapper);
        inToken.approve(address(repermit), type(uint256).max);
    }

    function test_Execute_SwapTheFullAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountPartial = inAmount;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.1 ether;

        SignedOrder[] memory orders = createOrderPartialOrder(inAmount, inAmountPartial, outAmount, outAmountGas);
    
        simulateSwap(inAmountPartial, outAmount, outAmountGas, orders);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.1 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inTokenTotalSupply - inAmountPartial, "user has the correct inToken balance");
    }

    function test_Execute_SwapTwice() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountPartial = 0.5 ether; // 50%
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.1 ether;

        SignedOrder[] memory orders = createOrderPartialOrder(inAmount, inAmountPartial, outAmount, outAmountGas);
        simulateSwap(inAmountPartial, outAmount, outAmountGas, orders);

        assertEq(outToken.balanceOf(swapper), 0.25 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.05 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inTokenTotalSupply - inAmountPartial, "user has the correct inToken balance");

        simulateSwap(inAmountPartial, outAmount, outAmountGas, orders);

        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.1 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inTokenTotalSupply - inAmountPartial * 2, "no inToken leftovers");
    }

    function test_Execute_SwapPartialAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountPartial = 0.4 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;

        SignedOrder[] memory orders = createOrderPartialOrder(inAmount, inAmountPartial, outAmount, outAmountGas);
        simulateSwap(inAmountPartial, outAmount, outAmountGas, orders);

        assertEq(outToken.balanceOf(swapper),  0.2 ether, "swapper end outAmount");
        assertEq(outToken.balanceOf(address(config.treasury)), 0.028 ether, "gas fee");
        assertEq(inToken.balanceOf(address(config.executor)), 0, "no inToken leftovers");
        assertEq(outToken.balanceOf(address(config.executor)), 0, "no outToken leftovers");
        assertEq(inToken.balanceOf(address(swapper)), inTokenTotalSupply - inAmountPartial, "no inToken leftovers");
    }


    function test_Revert_SwapInsffucientAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountPartial = 1.01 ether; // 101%
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;

        SignedOrder[] memory orders = createOrderPartialOrder(inAmount, inAmountPartial, outAmount, outAmountGas);
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), inAmountPartial));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, address(0)));
        config.executor.execute(orders, calls);

    }


    function test_Revert_GreaterThanInAmount() public {
        uint256 inAmount = 1 ether;
        uint256 inAmountPartial = 0.75 ether;
        uint256 outAmount = 0.5 ether;
        uint256 outAmountGas = 0.07 ether;

        SignedOrder[] memory orders = createOrderPartialOrder(inAmount, inAmountPartial, outAmount, outAmountGas);
        simulateSwap(inAmountPartial, outAmount, outAmountGas, orders);
        
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), inAmountPartial));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        assertEq(inToken.balanceOf(address(swapper)), inTokenTotalSupply - inAmountPartial, "no inToken leftovers");

        hoax(config.treasury.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, address(0.75 ether)));
        config.executor.execute(orders, calls);
    }

    function createOrderPartialOrder(uint256 inAmount, uint256 inAmountPartial, uint256 outAmount, uint256 outAmountGas) internal view returns (SignedOrder[] memory orders) {
        orders = new SignedOrder[](1);
        orders[0] = createAndSignPartialOrder(
            address(repermit),
            swapper,
            swapperPK,
            address(inToken),
            address(outToken),
            inAmount,
            inAmountPartial,
            outAmount,
            outAmountGas
        );
    }


    function simulateSwap(uint256 inAmountPartial, uint256 outAmount, uint256 outAmountGas, SignedOrder[] memory orders) internal {
    
        Call[] memory calls = new Call[](2);
        calls[0] =
            Call(address(inToken), abi.encodeWithSelector(inToken.burn.selector, address(config.executor), inAmountPartial));
        calls[1] = Call(
            address(outToken),
            abi.encodeWithSelector(outToken.mint.selector, address(config.executor), outAmount + outAmountGas + 1)
        );

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);
    }
}
