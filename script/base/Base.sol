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

    function createOrder(RFQ memory rfq) public view returns (Order memory result) {
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
    }

    error AlreadyDeployed(address);

    function requireFreshAddress(bytes memory creationCode, bytes memory abiEncodedArgs)
        public
        view
        returns (address result)
    {
        result = computeCreate2Address(0, hashInitCode(creationCode, abiEncodedArgs));
        if (result.code.length != 0) {
            revert AlreadyDeployed(result);
        }
    }
}
