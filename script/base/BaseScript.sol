// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

import {Base} from "script/base/Base.sol";
import {Workbench} from "script/base/Workbench.sol";
import {DeployTestInfra} from "script/base/DeployTestInfra.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";

abstract contract BaseScript is Base {
    function setUp() public {
        initMainnetFork();
    }
}
