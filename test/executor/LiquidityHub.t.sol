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
import {Admin} from "src/Admin.sol";
import {USDTMock} from "test/mocks/USDTMock.sol";

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

contract LiquidityHubUnitTest is BaseTest {
    LiquidityHub public hub;
    MockReactor public reactor;

    event ExtraOut(address indexed recipient, address token, uint256 amount);

    function setUp() public override {
        super.setUp();
        reactor = new MockReactor();
        hub = new LiquidityHub(multicall, address(reactor), admin);
    }

    function test_validate_allows_only_self_as_filler() public view {
        hub.validate(address(hub), _dummyResolvedOrder(address(token), 0));
    }

    function test_validate_reverts_for_others() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, other));
        hub.validate(other, _dummyResolvedOrder(address(token), 0));
    }

    function test_execute_reverts_when_not_allowed() public {
        // revoke this test address
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, false);

        // minimal ExclusiveDutchOrder encoding for execute
        ExclusiveDutchOrder memory ex;
        ex.info = OrderInfo({
            reactor: IReactor(address(reactor)),
            swapper: signer,
            nonce: 1,
            deadline: block.timestamp + 1 days,
            additionalValidationContract: IValidationCallback(address(0)),
            additionalValidationData: abi.encode(address(0), uint8(0))
        });
        ex.decayStartTime = block.timestamp;
        ex.decayEndTime = block.timestamp + 1 days;
        ex.exclusiveFiller = address(hub);
        ex.exclusivityOverrideBps = 0;
        ex.input = DutchInput({token: ERC20(address(token)), startAmount: 1, endAmount: 1});
        ex.outputs = new DutchOutput[](1);
        ex.outputs[0] = DutchOutput({token: address(token), startAmount: 1, endAmount: 1, recipient: signer});

        SignedOrder memory so;
        so.order = abi.encode(ex);
        so.sig = hex"";

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);

        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        hub.execute(so, calls, 0);
    }

    function test_reactorCallback_onlyReactor() public {
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);

        vm.expectRevert(abi.encodeWithSelector(LiquidityHub.InvalidSender.selector, address(this)));
        hub.reactorCallback(ros, abi.encode(calls, 0));
    }

    function test_reactorCallback_executes_multicall_and_sets_erc20_approval() public {
        // mint to hub via multicall (delegatecall)
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 1e18)
        });

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 1234);

        vm.prank(address(reactor));
        hub.reactorCallback(ros, abi.encode(calls, 0));

        assertEq(ERC20Mock(address(token)).balanceOf(address(hub)), 1e18);
        assertEq(IERC20(address(token)).allowance(address(hub), address(reactor)), 1234);
    }

    function test_reactorCallback_handles_usdt_like_tokens_approve_zero_first() public {
        USDTMock usdt = new USDTMock();

        // preset non-zero allowance from hub to reactor
        vm.prank(address(hub));
        usdt.approve(address(reactor), 1);

        // mint usdt to hub via multicall
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(usdt),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 1e18)
        });

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(usdt), 1234);

        vm.prank(address(reactor));
        hub.reactorCallback(ros, abi.encode(calls, 0));

        assertEq(IERC20(address(usdt)).allowance(address(hub), address(reactor)), 1235);
    }

    function test_reactorCallback_handles_eth_output_and_sends_to_reactor() public {
        vm.deal(address(hub), 1 ether);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(0), 987);

        uint256 beforeBal = address(reactor).balance;
        vm.prank(address(reactor));
        hub.reactorCallback(ros, abi.encode(calls, 0));
        assertEq(address(reactor).balance, beforeBal + 987);
    }

    function test_reactorCallback_emits_ExtraOut_for_non_swapper_recipient() public {
        // two outputs: 1 to swapper, 1 to other -> expect ExtraOut
        OutputToken[] memory outs = new OutputToken[](2);
        outs[0] = OutputToken({token: address(token), amount: 100, recipient: signer});
        outs[1] = OutputToken({token: address(token), amount: 50, recipient: other});

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        ros[0].outputs = outs;

        vm.expectEmit(true, true, true, true);
        emit ExtraOut(other, address(token), 50);

        vm.prank(address(reactor));
        hub.reactorCallback(ros, abi.encode(new IMulticall3.Call[](0), 0));
    }

    function test_reactorCallback_reverts_on_mixed_out_tokens_to_swapper() public {
        // two outputs to swapper with different valid ERC20 tokens -> InvalidOrder
        ERC20Mock token2 = new ERC20Mock();
        OutputToken[] memory outs = new OutputToken[](2);
        outs[0] = OutputToken({token: address(token), amount: 100, recipient: signer});
        outs[1] = OutputToken({token: address(token2), amount: 1, recipient: signer});

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        ros[0].outputs = outs;

        vm.prank(address(reactor));
        vm.expectRevert(LiquidityHub.InvalidOrder.selector);
        hub.reactorCallback(ros, abi.encode(new IMulticall3.Call[](0), 0));
    }

    function test_reactorCallback_transfers_delta_to_swapper_when_outAmountSwapper_greater() public {
        // mint extra outToken to hub via multicall
        ERC20Mock out = new ERC20Mock();
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(out),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 100)
        });

        // resolved order returns 500 to swapper; request 600 to swapper -> transfer 100 from hub
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(out), 500);

        uint256 before = out.balanceOf(signer);
        vm.prank(address(reactor));
        hub.reactorCallback(ros, abi.encode(calls, 600));
        assertEq(out.balanceOf(signer), before + 100);
    }

    function _dummyResolvedOrder(address outToken, uint256 outAmount)
        internal
        view
        returns (ResolvedOrder memory ro)
    {
        OrderInfo memory info = OrderInfo({
            reactor: IReactor(address(reactor)),
            swapper: signer,
            nonce: 0,
            deadline: block.timestamp + 1 days,
            additionalValidationContract: IValidationCallback(address(0)),
            additionalValidationData: abi.encode(address(0))
        });
        InputToken memory input = InputToken({token: ERC20(address(token)), amount: 0, maxAmount: 0});

        OutputToken[] memory outputs = new OutputToken[](1);
        outputs[0] = OutputToken({token: outToken, amount: outAmount, recipient: signer});

        ro = ResolvedOrder({info: info, input: input, outputs: outputs, sig: bytes(""), hash: bytes32(uint256(123))});
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
