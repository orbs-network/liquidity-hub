// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

import "./Workbench.sol";

contract BaseTest is Test {
    using StdStyle for string;
    using Workbench for Vm;

    Config public config;

    // ⛔️ JSON IS PARSED ALPHABETICALLY!
    struct Config {
        uint256 chainId;
        string chainName;
        address executor;
        address quoter;
        address reactor;
        address weth;
    }

    modifier withConfig() {
        // ⛔️ JSON IS PARSED ALPHABETICALLY!
        Config[] memory all = abi.decode(vm.parseJson(vm.readFile("configs.json")), (Config[]));
        for (uint256 i = 0; i < all.length; i++) {
            if (
                all[i].chainId == block.chainid
                    || keccak256(abi.encodePacked(vm.toUpper(all[i].chainName)))
                        == keccak256(abi.encodePacked(vm.toUpper(vm.envString("CHAIN_NAME"))))
            ) {
                config = all[i];
                console2.log("Forking:", config.chainName.bold().green());
                string memory urlEnvKey = string(abi.encodePacked("RPC_URL_", vm.toUpper(config.chainName)));
                vm.createSelectFork(vm.envString(urlEnvKey));
                console2.log(
                    string(
                        abi.encodePacked(
                            "block.chainid:",
                            vm.toString(block.chainid),
                            " block.number:",
                            vm.toString(block.number),
                            " date:",
                            vm.fmtDate(block.timestamp)
                        )
                    )
                );
                _;
                return;
            }
        }
        revert("no config");
    }

    modifier withMockConfig() {
        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: makeAddr("executor"),
            quoter: makeAddr("quoter"),
            reactor: makeAddr("reactor"),
            weth: address(new WETH())
        });
        vm.label(config.weth, "weth");
        _;
    }

    function setUp() public virtual {}
}
