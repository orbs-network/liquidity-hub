// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {Executor} from "src/executor/Executor.sol";
import {Admin} from "src/Admin.sol";

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {IValidationCallback} from "uniswapx/src/interfaces/IValidationCallback.sol";
import {ResolvedOrder, SignedOrder, OrderInfo, InputToken, OutputToken} from "uniswapx/src/base/ReactorStructs.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {USDTMock} from "test/mocks/USDTMock.sol";

contract ExecutorTest is BaseTest {
    Executor public exec;
    MockReactor public reactor;

    function setUp() public override {
        super.setUp();

        reactor = new MockReactor();
        exec = new Executor(multicall, address(reactor), admin);

        // allow this test as caller
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, true);
    }

    function test_execute_forwards_to_reactor_with_callback() public {
        SignedOrder memory so = _dummySignedOrder();
        bytes memory data = abi.encode(new IMulticall3.Call[](0));

        exec.execute(so, data);

        assertEq(reactor.lastSender(), address(exec));
        (bytes memory lastOrderBytes, ) = reactor.lastOrder();
        assertEq(keccak256(lastOrderBytes), keccak256(so.order));
        assertEq(keccak256(reactor.lastCallbackData()), keccak256(data));
    }

    function test_execute_reverts_when_not_allowed() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);
        Admin(admin).set(addrs, false);

        SignedOrder memory so = _dummySignedOrder();
        bytes memory data = bytes("");

        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, address(this)));
        exec.execute(so, data);
    }

    function test_reactorCallback_onlyReactor() public {
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 0);
        bytes memory data = abi.encode(new IMulticall3.Call[](0));

        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, address(this)));
        exec.reactorCallback(ros, data);
    }

    function test_reactorCallback_executes_multicall_and_sets_erc20_approval() public {
        // prepare multicall to mint to executor
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(exec), 1e18)
        });

        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(token), 1234);

        // call from reactor
        vm.prank(address(reactor));
        exec.reactorCallback(ros, abi.encode(calls));

        // multicall executed: executor now holds minted tokens
        assertEq(ERC20Mock(address(token)).balanceOf(address(exec)), 1e18);

        // approval set for reactor to allowance + amount
        assertEq(IERC20(address(token)).allowance(address(exec), address(reactor)), 1234);
    }

    function test_reactorCallback_handles_usdt_like_tokens_approve_zero_first() public {
        // deploy USDT-like token that reverts on non-zero->non-zero approvals
        USDTMock usdt = new USDTMock();

        // pre-set a non-zero allowance from executor to reactor
        vm.prank(address(exec));
        usdt.approve(address(reactor), 1);

        // mint to executor via multicall
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](1);
        calls[0] = IMulticall3.Call({
            target: address(usdt),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(exec), 1e18)
        });

        // resolved order outputs USDT to reactor via approval path
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(usdt), 1234);

        // call from reactor; should internally approve(0) then approve(1+1234)
        vm.prank(address(reactor));
        exec.reactorCallback(ros, abi.encode(calls));

        // final allowance == previous (1) + amount (1234)
        assertEq(IERC20(address(usdt)).allowance(address(exec), address(reactor)), 1235);
    }

    function test_reactorCallback_handles_eth_output_and_sends_to_reactor() public {
        // fund executor to cover sendValue
        vm.deal(address(exec), 1 ether);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](0);
        ResolvedOrder[] memory ros = new ResolvedOrder[](1);
        ros[0] = _dummyResolvedOrder(address(0), 987);

        uint256 beforeBal = address(reactor).balance;
        vm.prank(address(reactor));
        exec.reactorCallback(ros, abi.encode(calls));
        assertEq(address(reactor).balance, beforeBal + 987);
    }

    function test_validate_allows_only_self_as_filler() public view {
        exec.validate(address(exec), _dummyResolvedOrder(address(token), 0));
    }

    function test_validate_reverts_for_others() public {
        vm.expectRevert(abi.encodeWithSelector(Executor.InvalidSender.selector, other));
        exec.validate(other, _dummyResolvedOrder(address(token), 0));
    }

    function _dummySignedOrder() public pure returns (SignedOrder memory so) {
        so.order = hex"01";
        so.sig = hex"02";
    }

    function _dummyResolvedOrder(address outToken, uint256 outAmount) public view returns (ResolvedOrder memory ro) {
        OrderInfo memory info = OrderInfo({
            reactor: IReactor(address(reactor)),
            swapper: signer,
            nonce: 0,
            deadline: block.timestamp + 1 days,
            additionalValidationContract: IValidationCallback(address(0)),
            additionalValidationData: bytes("")
        });
        InputToken memory input = InputToken({token: ERC20(address(token)), amount: 0, maxAmount: 0});

        OutputToken[] memory outputs = new OutputToken[](1);
        outputs[0] = OutputToken({token: outToken, amount: outAmount, recipient: signer});

        ro = ResolvedOrder({info: info, input: input, outputs: outputs, sig: bytes(""), hash: bytes32(uint256(123))});
    }
}

contract MockReactor is IReactor {
    SignedOrder public lastOrder;
    bytes public lastCallbackData;
    address public lastSender;

    function execute(SignedOrder calldata) external payable {}

    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData) external payable {
        lastSender = msg.sender;
        lastOrder = order;
        lastCallbackData = callbackData;
    }

    function executeBatch(SignedOrder[] calldata) external payable {}

    function executeBatchWithCallback(SignedOrder[] calldata, bytes calldata) external payable {}

    receive() external payable {}
}
