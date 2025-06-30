// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {DeployLens} from "script/DeployLens.s.sol";

import {Lens, IERC20Metadata} from "src/Lens.sol";

contract LensTest is BaseTest {
    Lens public uut;

    function setUp() public override {
        // super.setUp();
        _chainBNB();
        uut = Lens(new DeployLens().run());
    }

    function test_observe() public {
        address token = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; // cake on bnb
        Lens.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertGt(result.tvl, 0, "TVL should be greater than 0");
        assertTrue(result.pool != address(0), "Pool should not be zero address");
    }

    function test_observe_decimals() public {
        address token = 0x76A797A59Ba2C17726896976B7B3747BfD1d220f; // ton on bnb with 9 decimals
        assertEq(IERC20Metadata(token).decimals(), 9, "Token should have 9 decimals");
        Lens.Observation memory result = uut.observe(token);
        assertLt(result.price, 100 ether, "Price should make sense for 9 decimals");
    }

    function test_observe_base() public {
        address token = uut.bases(0);
        Lens.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertEq(result.tvl, type(uint256).max, "TVL max because direct from oracle");
        assertTrue(result.pool == uut.oracles(0), "Pool should be oracle address");
    }

    function test_observe_native() public {
        address token = address(0);
        Lens.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
        assertEq(result.tvl, type(uint256).max, "TVL max because direct from oracle");
        assertTrue(result.pool == uut.oracles(0), "Pool should be oracle address");
    }

    function test_observe_4() public {
        address token = 0x991ceE7f782AbaefC9e1aA93B70b4f6Fc6C8326E;
        Lens.Observation memory result = uut.observe(token);
        assertGt(result.price, 0, "Price should be greater than 0");
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
