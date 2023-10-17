// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

struct Call {
    address target;
    bool allowFailure;
    bytes callData;
}

struct Result {
    bool success;
    bytes returnData;
}

interface IMulticall {
    function aggregate3(Call[] calldata calls) external payable returns (Result[] memory returnData);
}
