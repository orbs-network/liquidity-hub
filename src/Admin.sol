// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Admin is Ownable2Step {
    mapping(address => bool) public allowed;

    event AllowedSet(address indexed addr, bool allowed);

    constructor(address _owner) Ownable2Step() {
        allowed[_owner] = true;
        _transferOwnership(_owner);
    }

    function set(address[] calldata addr, bool _allowed) external onlyOwner {
        for (uint256 i = 0; i < addr.length; i++) {
            allowed[addr[i]] = _allowed;
            emit AllowedSet(addr[i], _allowed);
        }
    }
}
