// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping(address => bool) public enabled;

    constructor(address _owner) Ownable() {
        transferOwnership(_owner);
    }
}
