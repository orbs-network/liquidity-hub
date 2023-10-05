// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "./external/IWETH.sol";
import {IExchange} from "./exchange/IExchange.sol";

contract Treasury is Ownable {
    mapping(address => bool) public allowed;
    IWETH public weth;

    constructor(IWETH _weth, address _owner) Ownable() {
        weth = _weth;
        transferOwnership(_owner);
        allowed[_owner] = true;
    }

    error NotAllowed(address sender);
    error InsufficientOutput(uint256 amount);

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
        withdraw(new IExchange.Swap[](0), 0);
    }

    function withdraw(IExchange.Swap[] memory swaps, uint256 minAmount) public onlyAllowed {
        for (uint256 i = 0; i < swaps.length; i++) {
            IExchange.Swap memory s = swaps[i];
            Address.functionDelegateCall(
                address(s.exchange), abi.encodeWithSelector(IExchange.delegateSwap.selector, s)
            );
        }

        weth.withdraw(weth.balanceOf(address(this)));

        if (address(this).balance < minAmount) revert InsufficientOutput(address(this).balance);
        Address.sendValue(payable(owner()), address(this).balance);
    }

    receive() external payable {
        // accept ETH
    }
}
