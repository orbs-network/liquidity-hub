// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "@forge-std/Test.sol";

import "./Workbench.sol";

contract BaseTest is Test {
    using StdStyle for string;
    using Workbench for Vm;

    string[] private CHAINS = ["matic"];

    modifier chains() {
        for (uint256 i = 0; i < CHAINS.length; i++) {
            console2.log("Forking:", CHAINS[i].bold().green());
            vm.createSelectFork(vm.envString(string(abi.encodePacked("RPC_URL_", vm.toUpper(CHAINS[i])))));
            console2.log(block.chainid, block.number, vm.fmtDate(block.timestamp));
            _;
        }
    }

    function setUp() public chains {}

    function test_Increment() public {}
}
