// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {IEIP712} from "src/interface/IEIP712.sol";

import {RePermitLib} from "./RePermitLib.sol";

contract RePermit is EIP712, IEIP712 {
    using SafeERC20 for IERC20;

    error InvalidSignature();
    error Expired();
    error Canceled();
    error InsufficientAllowance(uint256 spent);

    // signer => hash => spent
    mapping(address => mapping(bytes32 => uint256)) public spent;
    // signer => nonce => canceled
    mapping(address => mapping(uint256 => bool)) public canceled;

    constructor() EIP712("RePermit", "1") {}

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function cancel(uint256 nonce) external {
        canceled[msg.sender][nonce] = true;
    }

    function repermitWitnessTransferFrom(
        RePermitLib.RePermitTransferFrom memory permit,
        RePermitLib.TransferRequest calldata request,
        address signer,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        if (block.timestamp > permit.deadline) revert Expired();
        if (canceled[signer][permit.nonce]) revert Canceled();

        bytes32 hash = _hashTypedDataV4(RePermitLib.hashWithWitness(permit, witness, witnessTypeString, msg.sender));
        if (!SignatureChecker.isValidSignatureNow(signer, hash, signature)) revert InvalidSignature();

        uint256 _spent = (spent[signer][hash] += request.amount); // increment and get
        if (_spent > permit.permitted.amount) revert InsufficientAllowance(_spent - request.amount);

        IERC20(permit.permitted.token).safeTransferFrom(signer, request.to, request.amount);
    }
}
