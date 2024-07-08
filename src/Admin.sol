// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Consts} from "./Consts.sol";
import {IWETH} from "./IWETH.sol";
import {IMulticall, Call} from "./IMulticall.sol";

contract Admin is Ownable {
    using SafeERC20 for IERC20;

    error NotAllowed(address sender);
    error BadParams();

    modifier onlyAllowed() {
        if (!allowed[msg.sender]) revert NotAllowed(msg.sender);
        _;
    }

    uint16 public constant BPS = 10_000;
    mapping(address => bool) public allowed;
    mapping(address => uint16) public shares;
    IWETH public weth;

    constructor(address _owner) Ownable() {
        allowed[_owner] = true;
        transferOwnership(_owner);
    }

    function initialize(address _weth) external onlyOwner {
        weth = IWETH(_weth);
    }

    function allow(address[] calldata addr, bool value) external onlyOwner {
        for (uint256 i = 0; i < addr.length;) {
            allowed[addr[i]] = value;
            unchecked {++i;}
        }
    }

    function share(address ref, uint16 bps) external onlyOwner {
        if (bps > BPS) revert BadParams();
        shares[ref] = bps;
    }

    function execute(Call[] calldata calls) external onlyOwner {
        Address.functionDelegateCall(
            Consts.MULTICALL_ADDRESS, abi.encodeWithSelector(IMulticall.aggregate.selector, calls)
        );
    }

    function withdraw(IERC20[] calldata tokens) external onlyAllowed {
        weth.withdraw(weth.balanceOf(address(this)));

        for (uint256 i = 0; i < tokens.length;) {
            uint256 balance = tokens[i].balanceOf(address(this));
            if (balance > 0) tokens[i].safeTransfer(owner(), balance);
            unchecked {++i;}
        }

        Address.sendValue(payable(owner()), address(this).balance);
    }

    receive() external payable {
        // accept ETH
    }
}
