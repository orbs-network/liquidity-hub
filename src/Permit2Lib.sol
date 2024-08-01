// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

library Permit2Lib {
    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";
    bytes32 internal constant TOKEN_PERMISSIONS_TYPE_HASH = keccak256(bytes(TOKEN_PERMISSIONS_TYPE));

    struct TokenPermissions {
        address token;
        uint256 amount;
    }
}
