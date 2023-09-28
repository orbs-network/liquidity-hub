// SPDX-License-Identifier: GPL-2.0-or-later
// License available at: https://github.com/Uniswap/UniswapX/blob/c478e248e01029cb28e6f851127f259e177e95a4/LICENSE
pragma solidity 0.8.x;

import {SignedOrder} from "./ReactorStructs.sol";

/// @notice Interface for order execution reactors
interface IReactor {
    /// @notice Execute a single order
    /// @param order The order definition and valid signature to execute
    function execute(SignedOrder calldata order) external payable;

    /// @notice Execute a single order using the given callback data
    /// @param order The order definition and valid signature to execute
    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData) external payable;

    /// @notice Execute the given orders at once
    /// @param orders The order definitions and valid signatures to execute
    function executeBatch(SignedOrder[] calldata orders) external payable;

    /// @notice Execute the given orders at once using a callback with the given callback data
    /// @param orders The order definitions and valid signatures to execute
    /// @param callbackData The callbackData to pass to the callback
    function executeBatchWithCallback(SignedOrder[] calldata orders, bytes calldata callbackData) external payable;

    function owner() external view returns (address);
}
