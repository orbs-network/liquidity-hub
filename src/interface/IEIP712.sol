// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function hashTypedData(bytes32 structHash) external view returns (bytes32 digest);
}
