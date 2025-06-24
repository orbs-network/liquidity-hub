// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Lens {
    using Math for uint256;

    uint256 public constant VERSION = 1;
    uint256 public constant TVL_THRESHOLD = 1000 ether;

    address public factory2;
    address public factory3;
    uint24[] public fees;
    address[] public bases;
    address[] public oracles;

    error InvalidInputs();

    struct Observation {
        uint256 price;
        uint256 tvl;
        address pool;
    }

    constructor(
        address _factory2,
        address _factory3,
        uint24[] memory _fees,
        address[] memory _bases,
        address[] memory _oracles
    ) {
        if (_bases.length == 0 || _bases.length != _oracles.length) revert InvalidInputs();
        factory2 = _factory2;
        factory3 = _factory3;
        fees = _fees;
        bases = _bases;
        oracles = _oracles;
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

            // Check Uniswap V2 pools
            Observation memory o = observePool2(token, base, decimalsToken, decimalsBase, usd);
            if (o.tvl > result.tvl) result = o;

            // Check Uniswap V3 pools
            for (uint256 j = 0; j < fees.length; j++) {
                uint24 fee = fees[j];

                o = observePool3(token, base, decimalsToken, decimalsBase, fee, usd);
                if (o.tvl > result.tvl) result = o;
            }
        }

        if (result.tvl < TVL_THRESHOLD) {
            delete result;
        }
    }

    function getUSD(uint256 index) public view returns (uint256 usd) {
        int256 answer = IOracle(oracles[index]).latestAnswer();
        if (answer <= 0) return 0;

        uint8 decimals = IERC20Metadata(oracles[index]).decimals();
        usd = uint256(answer) * 10 ** (18 - decimals);
    }

    function observePool3(address token, address base, uint8 decimalsToken, uint8 decimalsBase, uint24 fee, uint256 usd)
        public
        view
        returns (Observation memory result)
    {
        result.pool = IFactory3(factory3).getPool(token, base, fee);
        if (result.pool == address(0)) return result;

        uint128 liquidity = IUniswapV3Pool(result.pool).liquidity();
        if (liquidity == 0) return result;

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(result.pool).slot0();

        uint256 priceBase = getQuoteFromSqrtRatioX96(sqrtPriceX96, token, base, decimalsToken);
        result.price = Math.mulDiv(priceBase, usd, 1 ether);

        result.tvl = Math.mulDiv(IERC20(token).balanceOf(result.pool), result.price, 10 ** decimalsToken)
            + Math.mulDiv(IERC20(base).balanceOf(result.pool), usd, 10 ** decimalsBase);
    }

    function observePool2(address token, address base, uint8 decimalsToken, uint8 decimalsBase, uint256 usd)
        public
        view
        returns (Observation memory result)
    {
        result.pool = IFactory2(factory2).getPair(token, base);
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

    function getQuoteFromSqrtRatioX96(uint160 sqrtRatioX96, address token, address base, uint8 tokenDecimals)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        uint256 amt = 10 ** tokenDecimals;
        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = token < base ? Math.mulDiv(ratioX192, amt, 1 << 192) : Math.mulDiv(1 << 192, amt, ratioX192);
        } else {
            uint256 ratioX128 = Math.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = token < base ? Math.mulDiv(ratioX128, amt, 1 << 128) : Math.mulDiv(1 << 128, amt, ratioX128);
        }
    }
}

interface IFactory2 {
    function getPair(address token0, address token1) external view returns (address);
}

interface IUniswapV2Pool {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IFactory3 {
    function getPool(address token0, address token1, uint24 fee) external view returns (address);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128 liquidity);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );
}

interface IOracle {
    function latestAnswer() external view returns (int256);

    //TODO verify freshness
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
