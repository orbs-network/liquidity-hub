// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

import {Workbench} from "script/base/Workbench.sol";
import {DeployTestInfra} from "script/base/DeployTestInfra.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";

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

abstract contract Base is Script, DeployTestInfra {
    using Workbench for Vm;

    Config public config;
    address public deployer = msg.sender;

    function initMainnetFork() public {
        vm.chainId(137); // needed for config and permit2
        config = _readConfig();

        vm.label(address(config.treasury), "treasury");
        vm.label(address(config.executor), "executor");
        vm.label(address(config.reactor), "reactor");
        vm.label(address(config.weth), "weth");

        string memory urlEnvKey = string.concat("RPC_URL_", vm.toUpper(config.chainName));
        vm.createSelectFork(vm.envOr(urlEnvKey, vm.envString("ETH_RPC_URL")));

        deployer = vm.rememberKey(vm.envUint("DEPLOYER_PK"));
        vm.label(deployer, "deployer");
    }

    function initTestConfig() public {
        IReactor reactor = deployTestInfra();

        IWETH weth = IWETH(address(new WETH()));

        Treasury treasury = new Treasury(weth, deployer);
        LiquidityHub executor = new LiquidityHub(reactor, treasury);

        address quoter = makeAddr("quoter");

        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: executor,
            quoter: quoter,
            reactor: reactor,
            treasury: treasury,
            weth: weth
        });
    }

    function _readConfig() private view returns (Config memory) {
        string memory path =
            string.concat(vm.projectRoot(), "/script/input/", vm.toString(block.chainid), "/config.json");
        return abi.decode(vm.parseJson(vm.readFile(path)), (Config));
    }
}
