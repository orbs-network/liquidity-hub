// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

import {Workbench} from "test/Workbench.sol";

import {IReactor, Treasury, IWETH, IERC20} from "src/LiquidityHub.sol";

abstract contract BaseTest is Test {
    using StdStyle for string;
    using Workbench for Vm;

    Config public config;

    // ⛔️ JSON IS PARSED ALPHABETICALLY!
    struct Config {
        uint256 chainId;
        string chainName;
        address executor;
        address quoter;
        IReactor reactor;
        Treasury treasury;
        IWETH weth;
    }

    modifier withMockConfig() {
        address owner = makeAddr("owner");
        IWETH weth = IWETH(address(new WETH()));
        Treasury treasury = new Treasury(weth, owner);
        IReactor reactor = IReactor(makeAddr("reactor"));
        address executor = makeAddr("executor");
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
        _;
    }

    modifier withConfig() {
        // ⛔️ JSON IS PARSED ALPHABETICALLY!
        Config[] memory all = abi.decode(vm.parseJson(vm.readFile("configs.json")), (Config[]));
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].chainId == block.chainid) {
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

    function dealWETH(address target, uint256 amount) public {
        hoax(target, amount);
        config.weth.deposit{value: amount}();
        assertEq(config.weth.balanceOf(target), amount);
    }
}
