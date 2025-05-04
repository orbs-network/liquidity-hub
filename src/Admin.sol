// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWETH} from "src/interface/IWETH.sol";

contract Admin is Ownable {
    using SafeERC20 for IERC20;

    address public immutable multicall;
    IWETH public weth;
    mapping(address => bool) public allowed;

    constructor(address _multicall, address _owner) Ownable() {
        multicall = _multicall;
        allowed[_owner] = true;
        transferOwnership(_owner);
    }

    function init(address _weth) external onlyOwner {
        if (address(weth) != address(0)) revert();
        weth = IWETH(_weth);
    }

    function allow(address[] calldata addr, bool value) external onlyOwner {
        for (uint256 i = 0; i < addr.length; i++) {
            allowed[addr[i]] = value;
        }
    }

    function execute(IMulticall3.Call3Value[] calldata calls) external onlyOwner {
        Address.functionDelegateCall(multicall, abi.encodeWithSelector(IMulticall3.aggregate3Value.selector, calls));
    }

    function transfer(address token, address recipient) external onlyOwner {
        if (token == address(0)) {
            uint256 amount = address(this).balance;
            if (amount > 0) Address.sendValue(payable(recipient), amount);
        } else {
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > 0) SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        }
    }

    receive() external payable {
        // accept ETH
    }
}
