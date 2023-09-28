// SPDX-License-Identifier: GPL-2.0-or-later
// License available at: https://github.com/Uniswap/UniswapX/blob/c478e248e01029cb28e6f851127f259e177e95a4/LICENSE
pragma solidity 0.8.x;

import {ResolvedOrder} from "./ReactorStructs.sol";

/// @notice Callback for executing orders through a reactor.
interface IReactorCallback {
    /// @notice Called by the reactor during the execution of an order
    /// @param resolvedOrders Has inputs and outputs
    /// @param callbackData The callbackData specified for an order execution
    /// @dev Must have approved each token and amount in outputs to the msg.sender
    function reactorCallback(ResolvedOrder[] memory resolvedOrders, bytes memory callbackData) external;
}
