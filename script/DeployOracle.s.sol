// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {BaseScript} from "script/base/BaseScript.sol";

import {Oracle} from "src/Oracle.sol";

contract DeployOracle is BaseScript {
    function run() public returns (address oracle) {
        if (block.chainid != 56) revert("DeployOracle: Unsupported chain");

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

        address factory2 = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
        address factory3 = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
        // address factory4 = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;

        uint24[] memory fees3 = new uint24[](4);
        fees3[0] = 100;
        fees3[1] = 500;
        fees3[2] = 2500;
        fees3[3] = 10000;

        uint24[] memory fees4 = new uint24[](6);
        fees4[0] = 25;
        fees4[1] = 100;
        fees4[2] = 500;
        fees4[3] = 2500;
        fees4[4] = 10000;
        fees4[5] = 0x800000; // hook fee

        // address[] memory hooks4 = new address[](3);
        // hooks4[0] = address(0);
        // hooks4[1] = 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d;

        // uint24[] memory tickspacings4 = new uint24[](5);
        // tickspacings4[0] = 1;
        // tickspacings4[1] = 10;
        // tickspacings4[2] = 60;
        // tickspacings4[3] = 200;
        // tickspacings4[4] = 500;

        bytes32 initCodeHash = keccak256(
            abi.encodePacked(type(Oracle).creationCode, abi.encode(bases, oracles, factory2, factory3, fees3))
        );
        console.logBytes32(initCodeHash);

        vm.startBroadcast();
        oracle = address(
            new Oracle{salt: 0xb16ee6fd430071cea75a694186527021a7c959fbf50035d766710b17cd54e7d6}(
                bases, oracles, factory2, factory3, fees3
            )
        );
        vm.stopBroadcast();
    }
}
