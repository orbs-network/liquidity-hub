// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ExclusiveDutchOrderReactor, IPermit2} from "uniswapx/src/reactors/ExclusiveDutchOrderReactor.sol";

import {LiquidityHub, IReactor, IAllowed} from "src/LiquidityHub.sol";
import {RePermit} from "src/RePermit.sol";
import {PartialOrderReactor} from "src/PartialOrderReactor.sol";

import {BaseScript, Admin, Consts} from "script/base/BaseScript.sol";

contract DeployZK is BaseScript {
    function run()
        public
        returns (
            address admin,
            address reactor,
            address reactor2,
            address executor,
            address repermit,
            address reactorPartial
        )
    {
        address owner = vm.envAddress("OWNER");
        address weth = vm.envAddress("WETH");

        admin = _admin(owner, weth, bytes32(uint256(0x9563)));
        //        _whitelist(Admin(payable(admin)));
        //
        //        fee00 = _admin(owner, weth, 0x55669ad6a3db66a4a3bbfe640c9faa64095a75a5228cf52464f4a449257ee6c5);
        //        fee01 = _admin(owner, weth, 0xab1462bd378a47c5676f45ed8b1f1de08ddf212e2525b6c82e7c2c11c41590d2);
        //
        //        reactor = _reactor(bytes32(uint256(0)));
        //        reactor2 = _reactor(bytes32(uint256(1)));
        //
        //        executor = _executor(reactor, admin);
        //        executorPCX = _executor(0xDB9D365b50E62fce747A90515D2bd1254A16EbB9, admin);
        //
        //        repermit = _repermit();
        //        reactorPartial = _partialreactor(repermit);
    }

    function _admin(address owner, address weth, bytes32 salt) private returns (address) {
        salt;
        vm.broadcast();
        Admin deployed = new Admin(owner);
        vm.broadcast();
        deployed.init(weth);
        return address(deployed);
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
        salt;
        vm.broadcast();
        reactor = address(new ExclusiveDutchOrderReactor(IPermit2(Consts.PERMIT2_ADDRESS), address(0)));
    }

    function _executor(address reactor, address admin) private returns (address executor) {
        vm.broadcast();
        executor = address(new LiquidityHub(IReactor(payable(reactor)), IAllowed(address(admin))));
    }

    function _repermit() private returns (address repermit) {
        vm.broadcast();
        repermit == address(new RePermit());
    }

    function _partialreactor(address repermit) private returns (address reactor) {
        vm.broadcast();
        reactor = address(new PartialOrderReactor(RePermit(repermit)));
    }
}
