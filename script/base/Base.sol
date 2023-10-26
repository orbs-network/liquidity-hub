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

        string memory urlEnvKey = string.concat("RPC_URL_", toUpper(config.chainName));
        vm.createSelectFork(vm.envOr(urlEnvKey, vm.envString("ETH_RPC_URL")));

        deployer = vm.rememberKey(vm.envUint("DEPLOYER_PK"));
        vm.label(deployer, "deployer");
    }

    function readConfig() internal view returns (Config memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory configFile = string.concat(inputDir, chainDir, "config.json");
        return abi.decode(vm.parseJson(vm.readFile(configFile)), (Config));
    }

    function toUpper(string memory str) internal pure returns (string memory) {
        bytes memory strb = bytes(str);
        bytes memory copy = new bytes(strb.length);
        for (uint256 i = 0; i < strb.length; i++) {
            bytes1 b = strb[i];
            if (b >= 0x61 && b <= 0x7A) {
                copy[i] = bytes1(uint8(b) - 32);
            } else {
                copy[i] = b;
            }
        }
        return string(copy);
    }
}
