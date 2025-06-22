// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Uni3Lens {
    using Math for uint256;
    using SafeMath for uint256;

    uint256 private constant Q192 = 2 ** 192;
    uint256 private constant TVL_THRESHOLD = 1000 ether; // $1000

    address public immutable factory;
    uint24[] public fees;
    address[] public bases;
    address[] public oracles;

    error InvalidInputs();

    constructor(address _factory, uint24[] memory _fees, address[] memory _bases, address[] memory _oracles) {
        factory = _factory;
        fees = _fees;
        bases = _bases;
        oracles = _oracles;
        if (oracles.length != bases.length) revert InvalidInputs();
    }

    function observe(address token) external view returns (uint256 price, uint256 tvl, address pool) {
        uint8 decimalsToken = IDecimals(token).decimals();

        for (uint256 i = 0; i < bases.length; i++) {
            address base = bases[i];
            uint8 decimalsBase = IDecimals(base).decimals();
            bool inverse = token > base;

            uint256 usd = getUSD(i);

            for (uint256 j = 0; j < fees.length; j++) {
                uint24 fee = fees[j];

                (uint256 _price, uint256 _tvl, address _pool) =
                    observePool(token, base, decimalsBase, decimalsToken, fee, inverse, usd);
                if (_tvl == 0 || _price == 0) continue;

                if (_tvl > tvl) {
                    price = _price;
                    tvl = _tvl;
                    pool = _pool;
                }
            }
        }
    }

    function getUSD(uint256 index) public view returns (uint256 usd) {
        int256 answer = IOracle(oracles[index]).latestAnswer();
        if (answer <= 0) return 0;

        uint8 decimals = IOracle(oracles[index]).decimals();
        usd = uint256(answer) * 10 ** (18 - decimals);
    }

    function observePool(
        address token,
        address base,
        uint8 decimalsBase,
        uint8 decimalsToken,
        uint24 fee,
        bool inverse,
        uint256 usd
    ) public view returns (uint256 price, uint256 tvl, address pool) {
        pool = IFactory(factory).getPool(token, base, fee);
        if (pool == address(0)) return (price, tvl, pool);

        uint128 liquidity = IUniswapV3Pool(pool).liquidity();
        if (liquidity == 0) return (price, tvl, pool);

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();

        uint256 priceBase = getQuoteFromSqrtRatioX96(sqrtPriceX96, inverse, decimalsBase, decimalsToken);
        price = Math.mulDiv(priceBase, usd, 1 ether);

        // TODO only in range liquidity as tvl
        tvl = Math.mulDiv(IERC20(token).balanceOf(pool), price, 10 ** decimalsToken)
            + Math.mulDiv(IERC20(base).balanceOf(pool), usd, 10 ** decimalsBase);
    }

    function getQuoteFromSqrtRatioX96(uint160 sqrtRatioX96, bool inverse, uint8 decimalsBase, uint8 decimalsToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        uint256 baseAmount = 10 ** (inverse ? decimalsBase : decimalsToken);
        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount =
                !inverse ? Math.mulDiv(ratioX192, baseAmount, 1 << 192) : Math.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = Math.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount =
                !inverse ? Math.mulDiv(ratioX128, baseAmount, 1 << 128) : Math.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}

interface IFactory {
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
    function token0() external view returns (IDecimals);
    function token1() external view returns (IDecimals);
}

interface IDecimals {
    function decimals() external view returns (uint8);
}

interface IOracle is IDecimals {
    function latestAnswer() external view returns (int256);

    //TODO verify freshness
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
