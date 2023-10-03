// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping(address => bool) public allowed;

    constructor(address _owner) Ownable() {
        transferOwnership(_owner);
        allowed[_owner] = true;
    }

    function set(address[] calldata _addrs, bool _allowed) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            allowed[_addrs[i]] = _allowed;
        }
    }
}
