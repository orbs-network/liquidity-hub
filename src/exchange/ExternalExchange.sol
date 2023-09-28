// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IExchange} from "./IExchange.sol";

/**
 * LiquidityHub Exchange delegating swaps using simple approve and call with arbitrary data.
 */
contract ExternalExchange is IExchange {
    using SafeERC20 for IERC20;

    /**
     * @dev data: call data
     */
    function delegateSwap(Swap calldata s) external {
        IERC20(s.token).safeIncreaseAllowance(s.to, s.amount);
        Address.functionCall(s.to, s.data, "external");
    }
}
