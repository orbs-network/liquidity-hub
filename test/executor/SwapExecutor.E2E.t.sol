// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BaseTest} from "test/base/BaseTest.sol";

import {SwapExecutor, SignedOrder, IMulticall3} from "src/executor/SwapExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, OrderInfo} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {DutchOutput, DutchInput} from "uniswapx/src/lib/DutchOrderLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockReactor} from "test/mocks/MockReactor.sol";

contract SwapExecutorE2ETest is BaseTest {
    SwapExecutor public hub;
    MockReactor public reactor;

    ERC20Mock public tokenOut;
    address public ref;
    uint8 public refShare = 10; // 10%

    function setUp() public override {
        super.setUp();
        reactor = new MockReactor();
        hub = new SwapExecutor(multicall, address(reactor), admin);
        tokenOut = new ERC20Mock();
        ref = makeAddr("ref");
    }

    function test_e2e_execute_callback_and_surplus() public {
        ExclusiveDutchOrder memory ex;
        ex.info = OrderInfo({
            reactor: IReactor(address(reactor)),
            swapper: signer,
            nonce: 1,
            deadline: block.timestamp + 1 days,
            additionalValidationContract: IValidationCallback(address(0)),
            additionalValidationData: abi.encode(ref, refShare)
        });
        ex.decayStartTime = block.timestamp;
        ex.decayEndTime = block.timestamp + 1 days;
        ex.exclusiveFiller = address(hub);
        ex.exclusivityOverrideBps = 0;
        ex.input = DutchInput({token: ERC20(address(token)), startAmount: 100, endAmount: 100});
        ex.outputs = new DutchOutput[](1);
        ex.outputs[0] = DutchOutput({token: address(tokenOut), startAmount: 500, endAmount: 500, recipient: signer});

        SignedOrder memory so;
        so.order = abi.encode(ex);
        so.sig = hex"";

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(tokenOut),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 1000)
        });
        calls[1] = IMulticall3.Call({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 200)
        });

        hub.execute(so, calls, 600);

        assertEq(IERC20(address(tokenOut)).allowance(address(hub), address(reactor)), 500);
        assertEq(tokenOut.balanceOf(ref), 90);
        assertEq(tokenOut.balanceOf(signer), 910);
        assertEq(token.balanceOf(ref), 20);
        assertEq(token.balanceOf(signer), 180);
        assertEq(tokenOut.balanceOf(address(hub)), 0);
        assertEq(token.balanceOf(address(hub)), 0);
    }
}
