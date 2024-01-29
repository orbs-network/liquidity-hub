// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {RePermitLib, IEIP712} from "./RePermitLib.sol";

contract RePermit is EIP712, IEIP712 {
    using SafeERC20 for IERC20;

    error InvalidSignature();
    error SignatureExpired();
    error InsufficientAllowance(uint256 spent);

    // signer => token => spender => nonce => spent
    mapping(address => mapping(address => mapping(address => mapping(uint256 => uint256)))) public spent;

    constructor() EIP712("RePermit", "1") {}

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function repermitWitnessTransferFrom(
        RePermitLib.RePermitTransferFrom memory permit,
        RePermitLib.TransferRequest calldata request,
        address signer,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        if (block.timestamp > permit.deadline) revert SignatureExpired();

        bytes32 hash = _hashTypedDataV4(RePermitLib.hashWithWitness(permit, witness, witnessTypeString, msg.sender));
        if (!SignatureChecker.isValidSignatureNow(signer, hash, signature)) revert InvalidSignature();

        uint256 _spent = spent[signer][permit.permitted.token][msg.sender][permit.nonce];
        if (_spent + request.amount > permit.permitted.amount) revert InsufficientAllowance(_spent);
        spent[signer][permit.permitted.token][msg.sender][permit.nonce] = _spent + request.amount;

        IERC20(permit.permitted.token).safeTransferFrom(signer, request.to, request.amount);
    }
}
