// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, ERC20Mock, IERC20, SignedOrder, Consts, IMulticall3} from "test/base/BaseTest.sol";

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
    address public ref;

    function setUp() public override {
        super.setUp();
        (taker, takerPK) = makeAddrAndKey("taker");
        (maker, makerPK) = makeAddrAndKey("maker");
        ref = makeAddr("ref");

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

    function test_e2e_exactMirrorMatch() public {
        uint256 wethTakerAmount = 1 ether; // taker input
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output

        uint256 usdcMakerAmount = 2510 * 10 ** 6; // maker input
        uint256 wethMakerAmount = 1 ether; // maker output

        uint256 usdcAmountGas = 1 * 10 ** 6;

        SignedOrder memory takerOrder = signedOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas, ref
        );

        SignedOrder memory makerOrder = signedPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
        );

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount)
        });
        calls[1] = IMulticall3.Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.execute.selector, makerOrder)
        });

        hoax(config.admin.owner());
        config.executor.execute(takerOrder, calls, 0);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), wethTakerAmount, "weth maker balance");
        assertEq(usdc.balanceOf(maker), usdcMakerStartBalance - usdcMakerAmount, "usdc maker balance");
        assertEq(usdc.balanceOf(address(config.admin)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(ref), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(ref), 0, "weth positive slippage");
    }

    function test_e2e_partialInputMatch() public {
        uint256 wethTakerAmount = 1 ether; // taker input
        uint256 usdcTakerAmount = 2500 * 10 ** 6; // taker output

        uint256 usdcMakerAmount = 25100 * 10 ** 6; // maker input
        uint256 wethMakerAmount = 10 ether; // maker output

        uint256 usdcAmountGas = 1 * 10 ** 6;

        SignedOrder memory takerOrder = signedOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas, ref
        );

        SignedOrder memory makerOrder = signedPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethTakerAmount
        );

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount)
        });
        calls[1] = IMulticall3.Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.execute.selector, makerOrder)
        });

        hoax(config.admin.owner());
        config.executor.execute(takerOrder, calls, 0);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), 1 ether, "maker bought 1 eth");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker), 2510 * 10 ** 6, "maker paid $2510");
        assertEq(usdc.balanceOf(address(config.admin)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(ref), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(ref), 0, "weth no slippage");
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

        SignedOrder memory takerOrder = signedOrder(
            taker, takerPK, address(weth), address(usdc), wethTakerAmount, usdcTakerAmount, usdcAmountGas, ref
        );

        SignedOrder memory makerOrder1 = signedPartialOrder(
            maker, makerPK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
        );

        SignedOrder memory makerOrder2 = signedPartialOrder(
            maker2, maker2PK, address(usdc), address(weth), usdcMakerAmount, wethMakerAmount, wethMakerAmount
        );

        SignedOrder[] memory makerOrders = new SignedOrder[](2);
        makerOrders[0] = makerOrder1;
        makerOrders[1] = makerOrder2;
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(weth),
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(config.reactorPartial), wethMakerAmount * 2)
        });
        calls[1] = IMulticall3.Call({
            target: address(config.reactorPartial),
            callData: abi.encodeWithSelector(BaseReactor.executeBatch.selector, makerOrders)
        });

        hoax(config.admin.owner());
        config.executor.execute(takerOrder, calls, 0);

        assertEq(weth.balanceOf(taker), wethTakerStartBalance - wethTakerAmount, "weth taker balance");
        assertEq(usdc.balanceOf(taker), usdcTakerAmount, "usdc taker balance");
        assertEq(weth.balanceOf(maker), 0.5 ether, "weth maker balance");
        assertEq(weth.balanceOf(maker2), 0.5 ether, "weth maker2 balance");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker), 1255 * 10 ** 6, "maker paid $1255");
        assertEq(usdcMakerStartBalance - usdc.balanceOf(maker2), 1255 * 10 ** 6, "maker2 paid $1255");
        assertEq(usdc.balanceOf(address(config.admin)), usdcAmountGas, "gas fee");
        assertEq(weth.balanceOf(address(config.executor)), 0, "no weth leftovers");
        assertEq(usdc.balanceOf(address(config.executor)), 0, "no usdc leftovers");
        assertEq(usdc.balanceOf(ref), 9 * 10 ** 6, "usdc positive slippage");
        assertEq(weth.balanceOf(ref), 0 ether, "weth positive slippage");
    }
}
