// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {LiquidityHub, SignedOrder, IMulticall3} from "src/executor/LiquidityHub.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {ResolvedOrder, OrderInfo, InputToken, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {DutchOutput, DutchInput} from "uniswapx/src/lib/DutchOrderLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract LiquidityHubE2ETest is BaseTest {
    LiquidityHub public hub;
    MockReactor public reactor;

    ERC20Mock public tokenOut;
    address public ref;
    uint8 public refShare = 10; // 10%

    function setUp() public override {
        super.setUp();

        reactor = new MockReactor();
        hub = new LiquidityHub(multicall, address(reactor), admin);

        tokenOut = new ERC20Mock();
        ref = makeAddr("ref");
    }

    function test_e2e_execute_callback_and_surplus() public {
        // Encode ExclusiveDutchOrder expected by LiquidityHub.execute for surplus distribution
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
        so.order = abi.encode(ex); // signature not validated in this test path
        so.sig = hex"";

        // Multicall mints to hub (delegatecall -> calls execute from hub's context)
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](2);
        calls[0] = IMulticall3.Call({
            target: address(tokenOut),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 1000)
        });
        calls[1] = IMulticall3.Call({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 200)
        });

        // Reactor will resolve to output 500 tokenOut for signer; request 600 to swapper -> hub sends delta 100
        hub.execute(so, calls, 600);

        // Reactor got approval for resolved out amount
        assertEq(IERC20(address(tokenOut)).allowance(address(hub), address(reactor)), 500);

        // After execute: surplus distribution (10% to ref, 90% to signer)
        // tokenOut: remaining 900 -> 90 to ref, 810 to signer
        assertEq(tokenOut.balanceOf(ref), 90);
        assertEq(tokenOut.balanceOf(signer), 910);

        // token (input) surplus: 200 -> 20 to ref, 180 to signer
        assertEq(token.balanceOf(ref), 20);
        assertEq(token.balanceOf(signer), 180);

        // Hub should not retain balances
        assertEq(tokenOut.balanceOf(address(hub)), 0);
        assertEq(token.balanceOf(address(hub)), 0);
    }
}

contract MockReactor is IReactor {
    function execute(SignedOrder calldata) external payable {}

    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData) external payable {
        // Build minimal ResolvedOrder to drive LiquidityHub.reactorCallback
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);

        OutputToken[] memory outs = new OutputToken[](1);
        outs[0] = OutputToken({token: address(abi.decode(order.order, (ExclusiveDutchOrder)).outputs[0].token), amount: 500, recipient: abi.decode(order.order, (ExclusiveDutchOrder)).info.swapper});

        (address r, ) = abi.decode(abi.decode(order.order, (ExclusiveDutchOrder)).info.additionalValidationData, (address, uint8));

        ros[0] = ResolvedOrder({
            info: OrderInfo({
                reactor: IReactor(address(this)),
                swapper: abi.decode(order.order, (ExclusiveDutchOrder)).info.swapper,
                nonce: 1,
                deadline: block.timestamp + 1 days,
                additionalValidationContract: IValidationCallback(address(0)),
                additionalValidationData: abi.encode(r)
            }),
            input: InputToken({token: ERC20(address(abi.decode(order.order, (ExclusiveDutchOrder)).input.token)), amount: 100, maxAmount: 100}),
            outputs: outs,
            sig: bytes("")
            ,
            hash: bytes32(uint256(123))
        });

        IReactorCallback(msg.sender).reactorCallback(ros, callbackData);
    }

    function executeBatch(SignedOrder[] calldata) external payable {}

    function executeBatchWithCallback(SignedOrder[] calldata, bytes calldata) external payable {}

    receive() external payable {}
}
