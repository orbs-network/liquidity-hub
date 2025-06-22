// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest} from "test/base/BaseTest.sol";

import {Uni3Lens} from "src/Uni3Lens.sol";

contract Uni3LensTest is BaseTest {
    Uni3Lens public uut;

    function setUp() public override {
        super.setUp();
        uint24[] memory fees = new uint24[](4);
        fees[0] = 500;
        fees[1] = 3000;
        fees[2] = 10000;

        address factory = makeAddr("factory");

        address[] memory bases = new address[](2);
        address[] memory oracles = new address[](2);
        bases[0] = makeAddr("base0");
        oracles[0] = makeAddr("oracle0");
        bases[1] = makeAddr("base1");
        oracles[1] = makeAddr("oracle1");
        uut = new Uni3Lens(factory, fees, bases, oracles);
    }

    function test_() public {}
}
