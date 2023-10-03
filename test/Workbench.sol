// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import "forge-std/Test.sol";

library Workbench {
    function fmtDate(Vm vm, uint256 timestamp) public returns (string memory) {
        string[] memory inputs = new string[](5);
        inputs[0] = "date";
        inputs[1] = "-juf";
        inputs[2] = "%s";
        inputs[3] = vm.toString(timestamp);
        inputs[4] = "+%Y-%m-%d %H:%M:%SZ";
        return string(vm.ffi(inputs));
    }

    function toUpper(Vm, string memory str) public pure returns (string memory) {
        bytes memory strb = bytes(str);
        bytes memory copy = new bytes(strb.length);
        for (uint256 i = 0; i < strb.length; i++) {
            bytes1 b = strb[i];
            if (b >= 0x61 && b <= 0x7A) {
                copy[i] = bytes1(uint8(b) - 32);
            } else {
                copy[i] = b;
            }
        }
        return string(copy);
    }
}
