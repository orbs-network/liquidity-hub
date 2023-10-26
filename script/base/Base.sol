// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";

abstract contract Base is Script {
    Config public config;
    address public deployer;

    // ⛔️ JSON IS PARSED ALPHABETICALLY!
    struct Config {
        uint256 chainId;
        string chainName;
        LiquidityHub executor;
        address quoter;
        IReactor reactor;
        Treasury treasury;
        IWETH weth;
    }

    function setUp() public virtual {
        vm.chainId(137); // needed for config and permit2
        config = readConfig();

        deployer = vm.rememberKey(vm.envUint("DEPLOYER_PK"));
        vm.label(deployer, "deployer");
    }

    function readConfig() internal view returns (Config memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory configFile = string.concat(inputDir, chainDir, "config.json");
        return abi.decode(vm.parseJson(vm.readFile(configFile)), (Config));
    }
}
