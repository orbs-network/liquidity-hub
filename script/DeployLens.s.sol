// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {Lens} from "src/Lens.sol";

contract DeployLens is BaseScript {
    function run() public returns (address lens) {
        if (block.chainid != 56) revert("DeployLens: Unsupported chain");

        uint24[] memory fees = new uint24[](4);
        fees[0] = 100;
        fees[1] = 500;
        fees[2] = 2500;
        fees[3] = 10000;

        address[] memory bases = new address[](5);
        address[] memory oracles = new address[](5);
        // wbnb
        bases[0] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        oracles[0] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
        // usdt
        bases[1] = 0x55d398326f99059fF775485246999027B3197955;
        oracles[1] = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
        // usdc
        bases[2] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        oracles[2] = 0x51597f405303C4377E36123cBc172b13269EA163;
        // eth
        bases[3] = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
        oracles[3] = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e;
        // btc
        bases[4] = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
        oracles[4] = 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;

        vm.startBroadcast();
        lens = address(
            new Lens(
                0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73,
                0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
                fees,
                bases,
                oracles
            )
        );
        vm.stopBroadcast();
    }
}
