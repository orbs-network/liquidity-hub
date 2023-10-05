// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWETH} from "./external/IWETH.sol";
import {IExchange} from "./exchange/IExchange.sol";

contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public allowed;
    IWETH public immutable weth;

    constructor(IWETH _weth, address _owner) Ownable() {
        weth = _weth;
        allowed[_owner] = true;
        transferOwnership(_owner);
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
            tokens[i].safeTransfer(owner(), tokens[i].balanceOf(address(this)));
        }
        weth.withdraw(weth.balanceOf(address(this)));
        Address.sendValue(payable(owner()), address(this).balance);
    }

    receive() external payable {
        // accept ETH
    }
}
