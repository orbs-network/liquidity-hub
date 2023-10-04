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

    function set(address[] calldata _addrs, bool _allowed) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            allowed[_addrs[i]] = _allowed;
        }
    }

    function get(address[] calldata _addrs) external view returns (bool[] memory) {
        bool[] memory results = new bool[](_addrs.length);
        for (uint256 i = 0; i < _addrs.length; i++) {
            results[i] = allowed[_addrs[i]];
        }
        return results;
    }

    function withdraw() external onlyOwner {
        withdraw(new IERC20[](0));
    }

    function withdraw(IERC20[] memory tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].transfer(owner(), tokens[i].balanceOf(address(this)));
        }
        if (weth.balanceOf(address(this)) > 0) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
        Address.sendValue(payable(owner()), address(this).balance);
    }

    receive() external payable {
        // accept ETH
    }
}
