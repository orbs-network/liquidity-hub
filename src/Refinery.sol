// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Refinery {
    uint256 public constant BPS = 10000;
    address public immutable multicall;
    IAdmin public immutable admin;

    error NotAllowed();

    modifier onlyAllowed() {
        if (!admin.allowed(msg.sender)) revert NotAllowed();
        _;
    }

    constructor(address _multicall, address _admin) {
        multicall = _multicall;
        admin = IAdmin(_admin);
    }

    function execute(IMulticall3.Call3Value[] calldata calls) external onlyAllowed {
        Address.functionDelegateCall(multicall, abi.encodeWithSelector(IMulticall3.aggregate3Value.selector, calls));
    }

    function transferTo(address token, address recipient, uint256 bps) external onlyAllowed {
        if (token == address(0)) {
            uint256 amount = address(this).balance * bps / BPS;
            if (amount > 0) Address.sendValue(payable(recipient), amount);
        } else {
            uint256 amount = IERC20(token).balanceOf(address(this)) * bps / BPS;
            if (amount > 0) SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        }
    }

    receive() external payable {
        // accept ETH
    }
}

interface IAdmin {
    function allowed(address) external view returns (bool);
}
