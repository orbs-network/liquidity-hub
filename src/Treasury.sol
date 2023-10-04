// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "./external/IWETH.sol";

contract Treasury is Ownable {
    mapping(address => bool) public allowed;
    IWETH public weth;

    constructor(IWETH _weth, address _owner) Ownable() {
        weth = _weth;
        transferOwnership(_owner);
        allowed[_owner] = true;
    }

    error NotAllowed(address sender);

    modifier onlyAllowed() {
        if (!allowed[msg.sender]) revert NotAllowed(msg.sender);
        _;
    }

    function setAllowed(address[] calldata _addrs, bool _allowed) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            allowed[_addrs[i]] = _allowed;
        }
    }

    function getAllowed(address[] calldata _addrs) external view returns (bool[] memory) {
        bool[] memory results = new bool[](_addrs.length);
        for (uint256 i = 0; i < _addrs.length; i++) {
            results[i] = allowed[_addrs[i]];
        }
        return results;
    }

    function withdraw() external onlyAllowed {
        withdraw(new IERC20[](0));
    }

    function withdraw(IERC20[] memory tokens) public onlyAllowed {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].transfer(owner(), tokens[i].balanceOf(address(this)));
        }
        weth.withdraw(weth.balanceOf(address(this)));
    }

    receive() external payable {
        Address.sendValue(payable(owner()), address(this).balance);
    }
}
