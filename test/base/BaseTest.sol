// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ExclusiveDutchOrder} from "uniswapx/src/lib/ExclusiveDutchOrderLib.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";
import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

import {DeployTestInfra} from "test/base/DeployTestInfra.sol";

import {LiquidityHub, IMulticall, IReactor, IERC20, SignedOrder} from "src/LiquidityHub.sol";
import {Treasury, IWETH} from "src/Treasury.sol";

abstract contract BaseTest is Test, PermitSignature, DeployTestInfra {
    Config public config;

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
        IReactor reactor = IReactor(deployTestInfra());
        address owner = makeAddr("owner");
        IWETH weth = IWETH(address(new WETH()));
        Treasury treasury = new Treasury(weth, owner);
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

    function dealWETH(address target, uint256 amount) public {
        hoax(target, amount);
        config.weth.deposit{value: amount}();
        assertEq(config.weth.balanceOf(target), amount);
    }

    function createOrder(
        address swapper,
        uint256 privateKey,
        address inToken,
        uint256 inAmount,
        address outToken,
        uint256 outAmount
    ) public view returns (SignedOrder memory result) {
        uint256 deadline = block.timestamp + 10 minutes;
        ExclusiveDutchOrder memory order;
        {
            order.info.reactor = config.reactor;
            order.info.swapper = swapper;
            order.info.nonce = block.timestamp;
            order.info.deadline = deadline;
            order.decayStartTime = deadline;
            order.decayEndTime = deadline;

            order.input.token = ERC20(inToken);
            order.input.startAmount = inAmount;
            order.input.endAmount = inAmount;

            order.outputs = OutputsBuilder.singleDutch(outToken, outAmount, outAmount, swapper);
        }
        bytes memory sig = signOrder(privateKey, PERMIT2_ADDRESS, order);
        result = SignedOrder({sig: sig, order: abi.encode(order)});
    }
}
