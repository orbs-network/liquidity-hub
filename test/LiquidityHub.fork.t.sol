// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest, ERC20Mock, IWETH} from "test/base/BaseTest.sol";

import {LiquidityHub, Treasury, SignedOrder, Call, Consts} from "src/LiquidityHub.sol";

contract LiquidityHubForkTest is BaseTest {
    address public constant PARASWAP = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    uint256 public swapperPK;
    address public swapper;

    function setUp() public override {
        super.setUp();
        initMainnetFork();
        (swapper, swapperPK) = makeAddrAndKey("swapper");
    }

    function testFork_Paraswap() public {
        address paraswapTokenProxy = IParaswap(PARASWAP).getTokenTransferProxy();
        assertNotEq(paraswapTokenProxy, address(0));

        ERC20 inToken = ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
        ERC20 outToken = ERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // USDT
        vm.label(address(inToken), "inToken");
        vm.label(address(outToken), "outToken");

        uint256 inAmount = 1000 * (10 ** inToken.decimals());
        uint256 outAmount = 900 * (10 ** outToken.decimals());

        hoax(swapper, 0);
        inToken.approve(Consts.PERMIT2_ADDRESS, inAmount);

        SignedOrder[] memory orders = new SignedOrder[](1);
        orders[0] = createAndSignOrder(swapper, swapperPK, address(inToken), address(outToken), inAmount, outAmount);

        Call[] memory calls = new Call[](2);
        calls[0] = Call(
            address(inToken), abi.encodeWithSelector(inToken.approve.selector, paraswapTokenProxy, type(uint256).max)
        );
        calls[1] = Call(
            PARASWAP,
            bytes(
                hex"a6886da900000000000000000000000000000000000000000000000000000000000000200000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000c2132d05d31c914a87c6611c10748aeb04b58e8f000000000000000000000000e592427a0aece92de3edee1f18e0157c05861564000000000000000000000000000000000000000000000000000000003b9aca000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000003b9825dc010000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000653bf13f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002201a3662f3bf3341b7b165a4731b67bf3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b2791bca1f2de4661ed88a30c99a7a9449aa84174000064c2132d05d31c914a87c6611c10748aeb04b58e8f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            )
        );

        deal(address(inToken), swapper, inAmount);
        assertEq(inToken.balanceOf(swapper), inAmount);

        hoax(config.treasury.owner());
        // config.executor.execute(orders, calls);

        assertEq(outToken.balanceOf(address(config.executor)), 0);
        // assertEq(outToken.balanceOf(swapper), outAmount);
        // assertGt(outToken.balanceOf(address(config.treasury)), 1);
    }
}

interface IParaswap {
    function getTokenTransferProxy() external view returns (address);
}
