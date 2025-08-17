// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BaseTest} from "test/base/BaseTest.sol";

import {SwapExecutor, SignedOrder, IMulticall3} from "src/executor/SwapExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, OrderInfo, InputToken, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {DutchOutput, DutchInput} from "uniswapx/src/lib/DutchOrderLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Admin} from "src/Admin.sol";
import {USDTMock} from "test/mocks/USDTMock.sol";
import {MockReactor} from "test/mocks/MockReactor.sol";

contract SwapExecutorTest is BaseTest {
    SwapExecutor public hub;
    MockReactor public reactor;

    event ExtraOut(address indexed recipient, address token, uint256 amount);

    function setUp() public override {
        super.setUp();
        reactor = new MockReactor();
        hub = new SwapExecutor(multicall, address(reactor), admin);
    }

    function test_validate_allows_only_self_as_filler() public view {
        hub.validate(address(hub), _dummyResolvedOrder(address(token), 0));
    }

    function test_validate_reverts_for_others() public {
        vm.expectRevert(abi.encodeWithSelector(SwapExecutor.InvalidSender.selector, other));
        hub.validate(other, _dummyResolvedOrder(address(token), 0));
    }

    function test_execute_reverts_when_not_allowed() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, false);

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

        vm.expectRevert(abi.encodeWithSelector(SwapExecutor.InvalidSender.selector, address(this)));
        hub.execute(so, calls, 0);
    }

    function test_reactorCallback_onlyReactor() public {
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);

        vm.expectRevert(abi.encodeWithSelector(SwapExecutor.InvalidSender.selector, address(this)));
        hub.reactorCallback(ros, abi.encode(calls, 0));
    }

    function test_reactorCallback_executes_multicall_and_sets_erc20_approval() public {
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

        vm.prank(address(hub));
        usdt.approve(address(reactor), 1);

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
        ERC20Mock token2 = new ERC20Mock();
        OutputToken[] memory outs = new OutputToken[](2);
        outs[0] = OutputToken({token: address(token), amount: 100, recipient: signer});
        outs[1] = OutputToken({token: address(token2), amount: 1, recipient: signer});

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        ros[0].outputs = outs;

        vm.prank(address(reactor));
        vm.expectRevert(SwapExecutor.InvalidOrder.selector);
        hub.reactorCallback(ros, abi.encode(new IMulticall3.Call[](0), 0));
    }

    function test_reactorCallback_transfers_delta_to_swapper_when_outAmountSwapper_greater() public {
        ERC20Mock out = new ERC20Mock();
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(out),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(hub), 100)
        });

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
