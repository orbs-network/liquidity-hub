// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {LiquidityHub, IReactor, IAllowed} from "src/LiquidityHub.sol";
import {RePermit} from "src/RePermit.sol";
import {PartialOrderReactor} from "src/PartialOrderReactor.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";

contract Deploy is BaseScript {
    function run() public returns (address admin, address reactor, address reactor2, address executor) {
        address owner = vm.envAddress("OWNER");
        address weth = vm.envAddress("WETH");

        //admin = _admin(owner, weth, bytes32(uint256(0x9563)));
        //_whitelist(Admin(payable(admin)));

        //address fee00 = _admin(owner, weth, 0x55669ad6a3db66a4a3bbfe640c9faa64095a75a5228cf52464f4a449257ee6c5);
        //address fee01 = _admin(owner, weth, 0xab1462bd378a47c5676f45ed8b1f1de08ddf212e2525b6c82e7c2c11c41590d2);
        //address fee02 = _admin(owner, weth, 0x668fa19c8dfec98130ebcc64b727ecf11105987af78936a05550a1f6679b16cc);
        //address fee03 = _admin(owner, weth, 0x7622f2bb307bda72700fbabe78b8f2bc76c8d4f214e47ca34aa96b4e980947ce);

        //reactor = _reactor(bytes32(uint256(0)));
        //reactor2 = _reactor(bytes32(uint256(1)));

        //executor = _executor(reactor, admin);
        //executor = _executor(0x35db01D1425685789dCc9228d47C7A5C049388d8, 0x000066320a467dE62B1548f46465abBB82662331);

        //repermit = _repermit();
        //reactorPartial = _partialreactor(repermit);
    }

    function _admin(address owner, address weth, bytes32 salt) private returns (address admin) {
        bytes32 initCodeHash = hashInitCode(type(Admin).creationCode, abi.encode(owner));
        console.logBytes32(initCodeHash);
        admin = computeCreate2Address(salt, initCodeHash);

        if (admin.code.length == 0) {
            vm.broadcast();
            Admin deployed = new Admin{salt: salt}(owner);

            require(admin == address(deployed), "admin mismatched address");

            vm.broadcast();
            deployed.init(weth);
        } else {
            require(address(Admin(payable(admin)).weth()) != address(0), "not initialized");
            require(Admin(payable(admin)).owner() == owner, "admin mismatched owner");
            console.log("admin already deployed");
        }
    }

    uint256 public constant BATCH_SIZE = 300;

    function _whitelist(Admin admin) private {
        if (address(admin).code.length == 0) {
            console.log("admin not deployed");
            return;
        }

        string memory path = string.concat(vm.projectRoot(), "/script/input/", "whitelist.json");
        address[] memory list = abi.decode(vm.parseJson(vm.readFile(path)), (address[]));

        if (admin.allowed(list[0]) && admin.allowed(list[list.length - 1])) {
            console.log("whitelist already updated");
            return;
        }

        for (uint256 i = 0; i < list.length; i += BATCH_SIZE) {
            uint256 size = i + BATCH_SIZE < list.length ? BATCH_SIZE : list.length - i;

            address[] memory batch = new address[](size);
            for (uint256 j = 0; j < size; j++) {
                batch[j] = list[i + j];
            }

            vm.broadcast();
            admin.allow(batch, true);

            console.log("whitelist updated, batch", i);
        }

        require(admin.allowed(admin.owner()), "owner not allowed?");
        require(admin.allowed(list[0]), "first not allowed?");
        require(admin.allowed(list[list.length - 1]), "last not allowed?");
    }

    function _reactor(bytes32 salt) private returns (address reactor) {
        reactor = computeCreate2Address(
            salt,
            hashInitCode(type(ExclusiveDutchOrderReactor).creationCode, abi.encode(Consts.PERMIT2_ADDRESS, address(0)))
        );

        if (reactor.code.length == 0) {
            vm.broadcast();
            ExclusiveDutchOrderReactor deployed =
                new ExclusiveDutchOrderReactor{salt: salt}(IPermit2(Consts.PERMIT2_ADDRESS), address(0));
            require(reactor == address(deployed), "reactor mismatched address");
        } else {
            console.log("reactor already deployed");
        }
    }

    function _executor(address reactor, address admin) private returns (address executor) {
        executor = computeCreate2Address(0, hashInitCode(type(LiquidityHub).creationCode, abi.encode(reactor, admin)));

        if (executor.code.length == 0) {
            vm.broadcast();
            LiquidityHub deployed = new LiquidityHub{salt: 0}(IReactor(payable(reactor)), IAllowed(address(admin)));
            require(executor == address(deployed), "executor mismatched address");
        } else {
            console.log("executor already deployed");
        }
    }

    function _repermit() private returns (address repermit) {
        repermit = computeCreate2Address(0, hashInitCode(type(RePermit).creationCode));

        if (repermit.code.length == 0) {
            vm.broadcast();
            require(repermit == address(new RePermit{salt: 0}()), "repermit mismatched address");
        } else {
            console.log("repermit already deployed");
        }
    }

    function _partialreactor(address repermit) private returns (address reactor) {
        reactor = computeCreate2Address(0, hashInitCode(type(PartialOrderReactor).creationCode, abi.encode(repermit)));

        if (reactor.code.length == 0) {
            vm.broadcast();
            PartialOrderReactor deployed = new PartialOrderReactor{salt: 0}(RePermit(repermit));
            require(reactor == address(deployed), "mismatched address");
        } else {
            console.log("partialreactor already deployed");
        }
    }
}
