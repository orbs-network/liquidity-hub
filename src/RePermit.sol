// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct PackedAllowance {
    uint160 amount;
    uint48 expiration;
    uint48 nonce;
}

struct PermitDetails {
    address token;
    uint160 amount;
    uint48 expiration;
    uint48 nonce;
}

struct PermitSingle {
    PermitDetails details;
    address spender;
    uint256 sigDeadline;
}

struct TokenPermissions {
    address token;
    uint256 amount;
}

struct PermitTransferFrom {
    TokenPermissions permitted;
    uint256 nonce;
    uint256 deadline;
}

struct SignatureTransferDetails {
    address to;
    uint256 requestedAmount;
}

contract RePermit {
    using SafeERC20 for IERC20;

    // owner => token => spender => allowance
    // mapping(address => mapping(address => mapping(address => uint256))) public allowance;

    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external {}
    function transferFrom(address from, address to, uint160 amount, address token) external {}

    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature,
        uint256 partialAmount
    ) external {
        // uint256 requestedAmount = transferDetails.requestedAmount;

        // if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        // if (requestedAmount > permit.permitted.amount) revert InvalidAmount(permit.permitted.amount);

        // signature.verify(_hashTypedData(dataHash), owner);

        // uint256 maxAmount = allowed.amount;
        // if (maxAmount != type(uint160).max) {
        //     if (amount > maxAmount) {
        //         revert InsufficientAllowance(maxAmount);
        //     } else {
        //         unchecked {
        //             allowed.amount = uint160(maxAmount) - amount;
        //         }
        //     }
        // }

        // ERC20(permit.permitted.token).safeTransferFrom(owner, transferDetails.to, partialAmount);
    }

    function permitWitness(
        PermitSingle memory permitSingle,
        address owner,
        bytes32 witness,
        string calldata witnessType,
        bytes calldata signature
    ) external {
        // if (block.timestamp > permit.sigDeadline) revert SignatureExpired(permit.sigDeadline);
        // signature.verify(_hashTypedData(permitSingle.hash()), owner);
        // _updateApproval(permitSingle.details, owner, permitSingle.spender);
    }
}
