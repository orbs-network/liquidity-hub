// SPDX-License-Identifier: MIT
pragma solidity 0.8.x;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

library RePermitLib {
    struct RePermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct TransferRequest {
        address to;
        uint256 amount;
    }

    string public constant REPERMIT_WITNESS_TRANSFER_FROM_TYPE =
        "RePermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    string public constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";
    bytes32 public constant TOKEN_PERMISSIONS_TYPE_HASH = keccak256(bytes(TOKEN_PERMISSIONS_TYPE));

    function hashWithWitness(
        RePermitTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeString,
        address spender
    ) internal pure returns (bytes32) {
        bytes32 typehash = keccak256(abi.encodePacked(REPERMIT_WITNESS_TRANSFER_FROM_TYPE, witnessTypeString));
        return keccak256(
            abi.encode(
                typehash,
                keccak256(abi.encode(TOKEN_PERMISSIONS_TYPE_HASH, permit.permitted)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }
}

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract RePermit is EIP712, IEIP712 {
    using SafeERC20 for IERC20;

    error InvalidSignature();
    error SignatureExpired(uint256 deadline);
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
        if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        uint256 _s = spent[signer][permit.permitted.token][msg.sender][permit.nonce];
        if (_s + request.amount > permit.permitted.amount) {
            revert InsufficientAllowance(_s);
        }

        bytes32 hash = _hashTypedDataV4(RePermitLib.hashWithWitness(permit, witness, witnessTypeString, msg.sender));
        if (!SignatureChecker.isValidSignatureNow(signer, hash, signature)) revert InvalidSignature();

        spent[signer][permit.permitted.token][msg.sender][permit.nonce] += request.amount;
        IERC20(permit.permitted.token).safeTransferFrom(signer, request.to, request.amount);
    }
}
