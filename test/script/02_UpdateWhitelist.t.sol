// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {BaseTest, Treasury} from "test/base/BaseTest.sol";

import {UpdateWhitelist} from "script/02_UpdateWhitelist.s.sol";

contract UpdateWhitelistTest is BaseTest {
    function test_UpdateBatched() public {
        UpdateWhitelist script = new UpdateWhitelist();
        script.initTestConfig();
        script.run();
        (,,,, Treasury treasury,) = script.config();
        assertTrue(treasury.allowed(0x5bCF21C33a7DFC6e5ed26f7439eF065075EA61cf));
    }
}
