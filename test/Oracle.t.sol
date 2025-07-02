// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {DeployOracle} from "script/DeployOracle.s.sol";

import {Oracle, IERC20Metadata} from "src/Oracle.sol";

contract OracleTest is BaseTest {
    Oracle public uut;

    function setUp() public override {
        // super.setUp();
        _chainBNB();
        uut = Oracle(new DeployOracle().run());
    }

    function test_observe() public {
        address token = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; // cake on bnb
        Oracle.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertGt(result.tvl, 0, "TVL should be greater than 0");
        assertTrue(result.pool != address(0), "Pool should not be zero address");
    }

    function test_observe_decimals() public {
        address token = 0x76A797A59Ba2C17726896976B7B3747BfD1d220f; // ton on bnb with 9 decimals
        assertEq(IERC20Metadata(token).decimals(), 9, "Token should have 9 decimals");
        Oracle.Observation memory result = uut.observe(token);
        assertLt(result.price, 100 ether, "Price should make sense for 9 decimals");
    }

    function test_observe_base() public {
        address token = uut.bases(2);
        Oracle.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertEq(result.tvl, type(uint256).max, "TVL max because direct from oracle");
        assertTrue(result.pool == uut.oracles(2), "Pool should be oracle address");
    }

    function test_observe_native() public {
        address token = address(0);
        Oracle.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertEq(result.tvl, type(uint256).max, "TVL max because direct from oracle");
        assertTrue(result.pool == uut.oracles(0), "Pool should be oracle address");
    }

    function test_observe_safe() public {
        // this token reverts due to on empty pool reserve
        address token = 0x7918201208BBc5D3b0C84689aFd46aB391c1D1ce;

        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(0);
        Oracle.Observation[] memory result = uut.observe(tokens);
        assertEq(result[0].price, 0, "Price should be 0 for token with empty pool reserve");
        assertGt(result[1].price, 0, "Price should be greater than 0");
    }

    function test_observe_v4() public {
        address token = 0x991ceE7f782AbaefC9e1aA93B70b4f6Fc6C8326E;
        Oracle.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
    }

    function test_observe_catch() public {
        address token = makeAddr("invalid_token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(-1));
        Oracle.Observation memory result = uut.observe(token);
        assertEq(result.price, 0, "Price should be 0");
    }

    function test_observe_catch2() public {
        address token = makeAddr("invalid_token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(9));

        vm.mockCall(token, abi.encodeWithSignature("getPool(address,address)"), abi.encode(makeAddr("invalid_pool")));

        Oracle.Observation memory result = uut.observe(token);
        assertEq(result.price, 0, "Price should be 0");
        assertEq(result.tokenDecimals, 9, "Token decimals should still be set");
    }

    function _chainBNB() private {
        string[] memory cmds = new string[](4);
        cmds[0] = "getchain";
        cmds[1] = "bnb";
        cmds[2] = "-u";
        cmds[3] = "|| true";
        string memory url = string(vm.ffi(cmds));
        vm.createSelectFork(vm.envOr("RPC_URL", url));
    }
}
