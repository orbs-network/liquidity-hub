// SPDX-License-Identifier: GPL-2.0-or-later
// License available at: https://github.com/Uniswap/UniswapX/blob/c478e248e01029cb28e6f851127f259e177e95a4/LICENSE
pragma solidity 0.8.x;

import {ResolvedOrder, OutputToken} from "./ReactorStructs.sol";

/// @notice Interface for getting fee outputs
interface IProtocolFeeController {
    /// @notice Get fee outputs for the given orders
    /// @param order The orders to get fee outputs for
    /// @return List of fee outputs to append for each provided order
    function getFeeOutputs(ResolvedOrder memory order) external view returns (OutputToken[] memory);
}
