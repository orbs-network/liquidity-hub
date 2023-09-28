// SPDX-License-Identifier: GPL-2.0-or-later
// License available at: https://github.com/Uniswap/UniswapX/blob/c478e248e01029cb28e6f851127f259e177e95a4/LICENSE
pragma solidity 0.8.x;

import {ResolvedOrder} from "./ReactorStructs.sol";

/// @notice Callback to validate an order
interface IValidationCallback {
    /// @notice Called by the reactor for custom validation of an order. Will revert if validation fails
    /// @param filler The filler of the order
    /// @param resolvedOrder The resolved order to fill
    function validate(address filler, ResolvedOrder calldata resolvedOrder) external view;
}
