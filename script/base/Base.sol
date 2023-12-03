// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";
import {DeployTestInfra} from "script/base/DeployTestInfra.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";

// ⛔️ JSON IS PARSED ALPHABETICALLY!
struct Config {
    uint256 chainId;
    string chainName;
    LiquidityHub executor;
    address payable feeRecipient;
    IReactor reactor;
    Treasury treasury;
    IWETH weth;
}

abstract contract Base is Script, DeployTestInfra {
    Config public config;
    address public deployer = msg.sender;

    function setUp() public virtual {
        initProductionConfig();
    }

    function initProductionConfig() public {
        uint256 chainId = vm.envOr("CHAIN", block.chainid);
        if (chainId != block.chainid) vm.chainId(chainId);
        config = _readConfig();

        vm.label(address(config.treasury), "treasury");
        vm.label(address(config.executor), "executor");
        vm.label(address(config.feeRecipient), "feeRecipient");
        vm.label(address(config.reactor), "reactor");
        vm.label(address(config.weth), "weth");

        uint256 pk = vm.envOr("DEPLOYER_PK", uint256(0));
        if (pk != 0) {
            deployer = vm.rememberKey(pk);
            vm.label(deployer, "deployer");
        }
    }

    function initTestConfig() public {
        IReactor reactor = deployTestInfra();

        IWETH weth = IWETH(address(new WETH()));

        Treasury treasury = new Treasury(weth, deployer);
        LiquidityHub executor = new LiquidityHub(reactor, treasury, payable(makeAddr("feeRecipient")));

        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: executor,
            feeRecipient: executor.feeRecipient(),
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
