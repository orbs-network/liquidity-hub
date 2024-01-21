// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {DeployTestInfra} from "script/base/DeployTestInfra.sol";

import {LiquidityHub, IReactor} from "src/LiquidityHub.sol";
import {Treasury, IWETH, Consts, IMulticall, IERC20} from "src/Treasury.sol";
import {PartialOrderLib, RePermit, RePermitLib} from "src/PartialOrderReactor.sol";
import {IEIP712} from "src/RePermit.sol";
import "forge-std/console.sol";

// ⛔️ JSON IS PARSED ALPHABETICALLY!
struct Config {
    uint256 chainId;
    string chainName;
    LiquidityHub executor;
    address payable feeRecipient;
    IReactor reactor;
    address repermit;
    Treasury treasury;
    IWETH weth;
}

abstract contract Base is Script, DeployTestInfra {
    Config public config;
    address public deployer = msg.sender;
    uint256 public deployerPK;

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
        vm.label(address(config.repermit), "repermit");
        vm.label(address(config.weth), "weth");

        deployerPK = vm.envOr("DEPLOYER_PK", uint256(0));
        if (deployerPK != 0) {
            deployer = vm.rememberKey(deployerPK);
            vm.label(deployer, "deployer");
        }
    }

    function initTestConfig() public {
        IReactor reactor = deployTestInfra();

        IWETH weth = IWETH(address(new WETH()));

        Treasury treasury = new Treasury(weth, deployer);
        LiquidityHub executor = new LiquidityHub(reactor, treasury, payable(makeAddr("feeRecipient")));

        address repermit = address(new RePermit());

        config = Config({
            chainId: block.chainid,
            chainName: "anvil",
            executor: executor,
            feeRecipient: executor.feeRecipient(),
            reactor: reactor,
            repermit: repermit,
            treasury: treasury,
            weth: weth
        });
    }

    function _readConfig() private view returns (Config memory) {
        string memory path =
            string.concat(vm.projectRoot(), "/script/input/", vm.toString(block.chainid), "/config.json");
        return abi.decode(vm.parseJson(vm.readFile(path)), (Config));
    }

    function signPermit2(uint256 privateKey, bytes32 orderHash) internal view returns (bytes memory sig) {
        bytes32 msgHash = ECDSA.toTypedDataHash(IEIP712(Consts.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(), orderHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function signRePermit(address repermit, uint256 privateKey, PartialOrderLib.PartialOrder memory order)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 msgHash = ECDSA.toTypedDataHash(
            IEIP712(repermit).DOMAIN_SEPARATOR(),
            RePermitLib.hashWithWitness(
                RePermitLib.RePermitTransferFrom(
                    RePermitLib.TokenPermissions(address(order.input.token), order.input.amount),
                    order.info.nonce,
                    order.info.deadline
                ),
                PartialOrderLib.hash(order),
                PartialOrderLib.WITNESS_TYPE,
                address(config.reactor)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }
}
