// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Uni2Lens {
    using Math for uint256;

    uint256 public constant TVL_THRESHOLD = 1000 ether; // $1000

    address public immutable factory;
    address[] public bases;
    address[] public oracles;

    error InvalidInputs();

    struct Observation {
        uint256 price;
        uint256 tvl;
        address pool;
    }

    constructor(address _factory, address[] memory _bases, address[] memory _oracles) {
        factory = _factory;
        bases = _bases;
        oracles = _oracles;
        if (bases.length == 0 || bases.length != oracles.length) revert InvalidInputs();
    }

    function observe(address[] memory tokens) external view returns (Observation[] memory results) {
        results = new Observation[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            results[i] = observe(tokens[i]);
        }
    }

    function observe(address token) public view returns (Observation memory result) {
        if (token == address(0)) token = bases[0];

        uint8 decimalsToken = IERC20Metadata(token).decimals();

        for (uint256 i = 0; i < bases.length; i++) {
            address base = bases[i];
            uint256 usd = getUSD(i);

            if (token == base) {
                result.price = Math.mulDiv(usd, (10 ** decimalsToken), 1 ether);
                result.tvl = type(uint256).max; // direct from oracle
                result.pool = oracles[i];
                return result;
            }

            uint8 decimalsBase = IERC20Metadata(base).decimals();

            Observation memory o = observePool(token, base, decimalsToken, decimalsBase, usd);

            if (o.tvl > result.tvl && o.tvl >= TVL_THRESHOLD) {
                result.price = o.price;
                result.tvl = o.tvl;
                result.pool = o.pool;
            }
        }
    }

    function getUSD(uint256 index) public view returns (uint256 usd) {
        int256 answer = IOracle(oracles[index]).latestAnswer();
        if (answer <= 0) return 0;

        uint8 decimals = IERC20Metadata(oracles[index]).decimals();
        usd = uint256(answer) * 10 ** (18 - decimals);
    }

    function observePool(address token, address base, uint8 decimalsToken, uint8 decimalsBase, uint256 usd)
        public
        view
        returns (Observation memory result)
    {
        result.pool = IFactory(factory).getPair(token, base);
        if (result.pool == address(0)) return result;

        (uint112 r0, uint112 r1,) = IUniswapV2Pool(result.pool).getReserves();
        address t0 = IUniswapV2Pool(result.pool).token0();
        uint256 rT = token == t0 ? r0 : r1;
        uint256 rB = token == t0 ? r1 : r0;

        uint256 priceBase = (decimalsToken >= decimalsBase)
            ? Math.mulDiv(rB * 10 ** (decimalsToken - decimalsBase), 1 ether, rT)
            : Math.mulDiv(rB, 1 ether, rT * 10 ** (decimalsBase - decimalsToken));

        result.price = Math.mulDiv(priceBase, usd, 1 ether);

        result.tvl = Math.mulDiv(rT, result.price, 10 ** decimalsToken) + Math.mulDiv(rB, usd, 10 ** decimalsBase);
    }
}

interface IFactory {
    function getPair(address token0, address token1) external view returns (address);
}

interface IUniswapV2Pool {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IOracle {
    function latestAnswer() external view returns (int256);

    //TODO verify freshness
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
