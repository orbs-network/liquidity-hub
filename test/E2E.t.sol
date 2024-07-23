// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, SignedOrder, Consts, Call} from "test/base/BaseTest.sol";

import {PartialOrderReactor, RePermit, BaseReactor} from "src/PartialOrderReactor.sol";

contract E2ETest is BaseTest {
    address public taker;
    uint256 public takerPK;
    address public maker;
    uint256 public makerPK;
    ERC20Mock public weth;
    ERC20Mock public usdc;
    uint256 public wethTakerStartBalance = 10 ether;
    uint256 public usdcMakerStartBalance = 25_000 * 10 ** 6;
    address public fees;

    function setUp() public override {
        super.setUp();
        (taker, takerPK) = makeAddrAndKey("taker");
        (maker, makerPK) = makeAddrAndKey("maker");
        fees = makeAddr("fees");

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
        uint256 wethTakerAmount = 1 ether; // taker input
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output

        uint256 usdcMakerAmount = 2510 * 10 ** 6; // maker input
        uint256 wethMakerAmount = 1 ether; // maker output

        uint256 usdcAmountGas = 1 * 10 ** 6;

        SignedOrder memory takerOrder = createAndSignOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas
        );

        SignedOrder memory makerOrder = createAndSignPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
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
        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls, fees, tokens);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), wethTakerAmount, "weth maker balance");
        assertEq(usdc.balanceOf(maker), usdcMakerStartBalance - usdcMakerAmount, "usdc maker balance");
        assertEq(usdc.balanceOf(address(config.treasury)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(fees), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(fees), 0, "weth positive slippage");
    }

    function test_e2e_PartialInputMatch() public {
        uint256 wethTakerAmount = 1 ether; // taker input
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output

        uint256 usdcMakerAmount = 25100 * 10 ** 6; // maker input
        uint256 wethMakerAmount = 10 ether; // maker output

        uint256 usdcAmountGas = 1 * 10 ** 6;

        SignedOrder memory takerOrder = createAndSignOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas
        );

        SignedOrder memory makerOrder = createAndSignPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethTakerAmount
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
        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls, fees, tokens);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), 1 ether, "maker bought 1 eth");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker), 2510 * 10 ** 6, "maker paid $2510");
        assertEq(usdc.balanceOf(address(config.treasury)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(fees), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(fees), 0, "weth no slippage");
    }

    function test_e2e_multiplePartialInputs() public {
        uint256 wethTakerAmount = 1 ether; // taker input
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output

        uint256 usdcMakerAmount = 1255 * 10 ** 6; // maker input
        uint256 wethMakerAmount = 0.5 ether; // maker output

        (address maker2, uint256 maker2PK) = makeAddrAndKey("maker2");
        usdc.mint(maker2, usdcMakerStartBalance);
        hoax(maker2);
        usdc.approve(address(config.repermit), type(uint256).max);

        uint256 usdcAmountGas = 1 * 10 ** 6;

        SignedOrder memory takerOrder = createAndSignOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas
        );

        SignedOrder memory makerOrder1 = createAndSignPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
        );

        SignedOrder memory makerOrder2 = createAndSignPartialOrder(
            maker2, maker2PK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
        );

        SignedOrder[] memory orders = new SignedOrder[](1);

        SignedOrder[] memory makerOrders = new SignedOrder[](2);
        makerOrders[0] = makerOrder1;
        makerOrders[1] = makerOrder2;
        orders[0] = takerOrder;
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount * 2)
        });
        calls[1] = Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.executeBatch.selector, makerOrders)
        });
        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        hoax(config.treasury.owner());
        config.executor.execute(orders, calls, fees, tokens);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), 0.5 ether, "weth maker balance");
        assertEq(weth.balanceOf(maker2), 0.5 ether, "weth maker2 balance");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker), 1255 * 10 ** 6, "maker paid $1255");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker2), 1255 * 10 ** 6, "maker2 paid $1255");
        assertEq(usdc.balanceOf(address(config.treasury)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(fees), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(fees), 0 ether, "weth positive slippage");
    }
}
