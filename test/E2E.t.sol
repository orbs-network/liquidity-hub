// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, IWETH, SignedOrder, Consts} from "test/base/BaseTest.sol";

import {PartialOrderReactor, RePermit, Call, BaseReactor} from "src/PartialOrderReactor.sol";

contract E2ETest is BaseTest {
    address public taker;
    uint256 public takerPK;
    address public maker;
    uint256 public makerPK;
    ERC20Mock public weth;
    ERC20Mock public usdc;
    uint256 public wethTakerStartBalance = 10 ether;
    uint256 public usdcMakerStartBalance = 25_000 * 10 ** 6;

    function setUp() public override {
        super.setUp();
        (taker, takerPK) = makeAddrAndKey("taker");
        (maker, makerPK) = makeAddrAndKey("maker");

        weth = new ERC20Mock();
        usdc = new ERC20Mock();
        vm.label(address(weth), "weth");
        vm.label(address(usdc), "usdc");

        weth.mint(taker, wethTakerStartBalance);
        usdc.mint(maker, usdcMakerStartBalance);

        hoax(taker);
        weth.approve(Consts.PERMIT2_ADDRESS, type(uint256).max);

        hoax(maker);
        usdc.approve(address(config.repermit), type(uint256).max);
    }

    function test_e2e_ExactMirrorMatch() public {
        uint256 wethTakerAmount = 1 ether; // taker input, selling 1 eth
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output, buying 2500 usdc
        // $2500

        uint256 usdcMakerAmount = 2510 * 10 ** 6; // maker input, selling 2510 usdc
        uint256 wethMakerAmount = 1 ether; // maker output, buying 1 eth
        // $2510

        uint256 usdcAmountGas = 1 * 10 ** 6; // 1 usdc gas fee, from maker's output

        SignedOrder memory takerOrder = createAndSignOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas
        );

        SignedOrder memory makerOrder = createAndSignPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, usdcMakerAmount, wethMakerAmount
        );

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = takerOrder;
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount)
        });
        calls[1] = Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.execute.selector, makerOrder)
        });
        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), wethTakerAmount, "weth maker balance");
        assertEq(usdc.balanceOf(maker), usdcMakerStartBalance - usdcMakerAmount, "usdc maker balance");
        assertEq(usdc.balanceOf(address(config.treasury)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(config.executor.feeRecipient()), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(config.executor.feeRecipient()), 0, "weth positive slippage");
    }

    function test_e2e_PartialInputMatch() public {
        uint256 wethTakerAmount = 1 ether; // taker input, selling 1 eth
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output, buying 2500 usdc
        // $2500

        uint256 usdcMakerAmount = 2510 * 10 ** 6; // maker input, selling 2510 usdc
        uint256 wethMakerAmount = 1 ether; // maker output, buying 1 eth
        // $2510

        uint256 usdcAmountGas = 1 * 10 ** 6; // 1 usdc gas fee, from maker's output

        SignedOrder memory takerOrder = createAndSignOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas
        );

        // $3000
        SignedOrder memory makerOrder = createAndSignPartialOrder(
            maker, makerPK, address(usdc), address(weth), 3000 * 10 ** 6, usdcMakerAmount, wethMakerAmount
        );

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = takerOrder;
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount)
        });
        calls[1] = Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.execute.selector, makerOrder)
        });
        hoax(config.treasury.owner());
        config.executor.execute(orders, calls);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), 0.836666666666666666 ether, "maker bought 0.8366 eth");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker), 2510 * 10 ** 6, "maker paid $2510");
        assertEq(usdc.balanceOf(address(config.treasury)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(config.executor.feeRecipient()), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(config.executor.feeRecipient()), 0.163333333333333334 ether, "weth positive slippage");
    }
}
