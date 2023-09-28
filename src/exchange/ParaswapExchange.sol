// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IExchange} from "./IExchange.sol";

/**
 * LiquidityHub Exchange delegating swaps to Paraswap
 */
contract ParaswapExchange is IExchange {
    using SafeERC20 for IERC20;

    IParaswap public constant paraswap = IParaswap(0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57);

    /**
     * @dev data: from paraswap api
     */
    function delegateSwap(Swap calldata s) external override {
        IERC20(s.token).safeIncreaseAllowance(paraswap.getTokenTransferProxy(), s.amount);
        Address.functionCall(address(paraswap), s.data, "paraswap");
    }
}

/**
 * Augustus Swapper
 * Paraswap main exchange interface
 */
interface IParaswap {
    function getTokenTransferProxy() external view returns (address);
}
