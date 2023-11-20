// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {ExclusiveDutchOrderLib, ExclusiveDutchOrder, DutchInput} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";

import {DeployTestInfra} from "script/base/DeployTestInfra.sol";

import {LiquidityHub, IReactor, IValidationCallback} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";

// ⛔️ JSON IS PARSED ALPHABETICALLY!
struct Config {
    uint256 chainId;
    string chainName;
    LiquidityHub executor;
    IReactor reactor;
    Treasury treasury;
    IWETH weth;
}

struct RFQ {
    address swapper;
    address inToken;
    address outToken;
    uint256 inAmount;
    uint256 outAmount;
}

struct Order {
    ExclusiveDutchOrder order;
    bytes encoded;
    bytes32 hash;
    string permitData;
}

abstract contract Base is Script, DeployTestInfra {
    Config public config;
    address public deployer = msg.sender; // the default foundry deployer

    function setUp() public virtual {
        initProductionConfig();
    }

    function initProductionConfig() public {
        uint256 chainId = vm.envOr("CHAIN", block.chainid);
        if (chainId != block.chainid) vm.chainId(chainId);
        config = _readConfig();

        vm.label(address(config.treasury), "treasury");
        vm.label(address(config.executor), "executor");
        vm.label(address(config.reactor), "reactor");
        vm.label(address(config.weth), "weth");

        deployer = vm.rememberKey(vm.envOr("DEPLOYER_PK", uint256(1)));
        vm.label(deployer, "deployer");
    }

    function initTestConfig() public {
        IReactor reactor = deployTestInfra();

        IWETH weth = IWETH(address(new WETH()));

        Treasury treasury = new Treasury(weth, deployer);
        LiquidityHub executor = new LiquidityHub(reactor, treasury);

        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: executor,
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

    function createOrder(RFQ memory rfq) public returns (Order memory result) {
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = rfq.swapper;
            order.info.nonce = block.timestamp;
            order.info.deadline = block.timestamp + 10 minutes;
            order.decayStartTime = order.info.deadline;
            order.decayEndTime = order.info.deadline;

            order.exclusiveFiller = address(config.executor);
            order.info.additionalValidationContract = IValidationCallback(config.executor);

            order.input.token = ERC20(rfq.inToken);
            order.input.startAmount = rfq.inAmount;
            order.input.endAmount = rfq.inAmount;

            order.outputs = OutputsBuilder.singleDutch(rfq.outToken, rfq.outAmount, rfq.outAmount, rfq.swapper);
        }
        result.order = order;
        result.encoded = abi.encode(order);
        result.hash = ExclusiveDutchOrderLib.hash(order);

        string[] memory cmd = new string[](13);
        cmd[0] = "sed";
        cmd[1] = string.concat("-e s@<CHAINID>@", vm.toString(block.chainid), "@g");
        cmd[2] = string.concat("-e s@<PERMIT2>@", vm.toString(Consts.PERMIT2_ADDRESS), "@g");
        cmd[3] = string.concat("-e s@<SWAPPER>@", vm.toString(rfq.swapper), "@g");
        cmd[4] = string.concat("-e s@<INTOKEN>@", vm.toString(rfq.inToken), "@g");
        cmd[5] = string.concat("-e s@<OUTTOKEN>@", vm.toString(rfq.outToken), "@g");
        cmd[6] = string.concat("-e s@<INAMOUNT>@", vm.toString(rfq.inAmount), "@g");
        cmd[7] = string.concat("-e s@<OUTAMOUNTSWAPPER>@", vm.toString(rfq.outAmount), "@g");
        // cmd[7] = string.concat("-e s@<OUTAMOUNTFEE>@", vm.toString(rfq.outAmount), "@g");
        // cmd[7] = string.concat("-e s@<OUTAMOUNTGAS>@", vm.toString(rfq.outAmount), "@g");
        cmd[8] = string.concat("-e s@<DEADLINE>@", vm.toString(order.info.deadline), "@g");
        cmd[9] = string.concat("-e s@<NONCE>@", vm.toString(order.info.nonce), "@g");
        cmd[10] = string.concat("-e s@<REACTOR>@", vm.toString(address(order.info.reactor)), "@g");
        cmd[11] = string.concat("-e s@<EXECUTOR>@", vm.toString(address(config.executor)), "@g");
        cmd[12] = "script/input/permit.skeleton.json";

        result.permitData = string(vm.ffi(cmd));
    }
}
