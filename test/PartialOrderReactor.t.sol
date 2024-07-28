// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, SignedOrder, Call} from "test/base/BaseTest.sol";

import {LiquidityHub} from "src/LiquidityHub.sol";
import {PartialOrderReactor, RePermit} from "src/PartialOrderReactor.sol";

contract PartialOrderReactorTest is BaseTest {
    address public swapper;
    uint256 public swapperPK;
    ERC20Mock public inToken;
    ERC20Mock public outToken;

    function setUp() public override {
        super.setUp();

        config.executor = LiquidityHub(payable(address(0))); // avoid exclusivity checks
        (swapper, swapperPK) = makeAddrAndKey("swapper");

        inToken = new ERC20Mock();
        outToken = new ERC20Mock();
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        inToken.mint(swapper, 10 ether);
        hoax(swapper);
        inToken.approve(address(config.repermit), type(uint256).max);
    }

    function test_execute_swapFullAmount() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.5 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount");
    }

    function test_execute_swapPartial() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9.5 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.25 ether, "swapper end outAmount, swap1");

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9 ether, "swapper inToken");
        assertEq(outToken.balanceOf(swapper), 0.5 ether, "swapper end outAmount, swap2");
    }

    function test_execute_swapPartialOdd() public {
        uint256 inAmount = 10 ether;
        uint256 outAmount = 30 ether;

        _execute(inAmount, outAmount, 7 ether);

        assertEq(inToken.balanceOf(address(swapper)), 10 ether - 2333333333333333333, "swapper inToken"); // floor the input
        assertEq(outToken.balanceOf(swapper), 7 ether, "swapper end outAmount");
    }

    function test_revert_requestGTSigned() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;
        SignedOrder memory order = signedPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0.6 ether
        );
        hoax(config.admin.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0));
        config.reactorPartial.execute(order);
    }

    function test_revert_insufficentAlowanceAfterSpending() public {
        uint256 inAmount = 1 ether;
        uint256 outAmount = 0.5 ether;

        _execute(inAmount, outAmount, 0.25 ether);

        assertEq(inToken.balanceOf(address(swapper)), 9.5 ether, "no inToken leftovers");

        SignedOrder memory order = signedPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, 0.5 ether
        );
        hoax(config.admin.owner());
        vm.expectRevert(abi.encodeWithSelector(RePermit.InsufficientAllowance.selector, 0.5 ether));
        config.reactorPartial.execute(order);
    }

    function _execute(uint256 inAmount, uint256 outAmount, uint256 fillOutAmount) private {
        SignedOrder memory order = signedPartialOrder(
            swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount, fillOutAmount
        );

        assertEq(inToken.balanceOf(address(this)), 0, "inToken pre swap balance");
        outToken.mint(address(this), outAmount);
        outToken.approve(address(config.reactorPartial), fillOutAmount);

        config.reactorPartial.execute(order);

        assertEq(inToken.balanceOf(address(this)), inAmount * fillOutAmount / outAmount, "inToken post swap balance");
        assertEq(outToken.balanceOf(address(this)), outAmount - fillOutAmount, "outToken post swap balance");
        inToken.burn(address(this), inToken.balanceOf(address(this)));
        outToken.burn(address(this), outToken.balanceOf(address(this)));
    }
}
