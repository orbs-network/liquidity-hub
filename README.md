# Reactor-Based Order System – **v1 Specification**

*limit, TWAP slice, optional trigger hint • single-oracle cosigner*

---

## 1 Components

| Name         | Responsibility                                                                                                                                                 |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Swapper**  | End-user who creates & signs an order.                                                                                                                         |
| **Vault**    | Off-chain service (DB + HTTPS API) that stores `(order, swapperSig)` and later receives the oracle’s price signature.                                          |
| **Oracle**   | Passive signer; returns a price signature only when the Executor requests it.                                                                                  |
| **Executor** | Off-chain engine that polls the Vault, asks the Oracle for a price, finds liquidity (router call **or off-chain RFQ**), and submits the on-chain `fill()` txn. |
| **Reactor**  | Solidity contract that verifies all signatures, enforces optional DEX-lock, and settles the swap.                                                              |

---

## 2 Data Structures (EIP-712)

### 2.1 Order

```solidity
struct Input {
  address tokenIn;
  uint256 amount;        // slice size (TWAP) or full size (limit)
  uint256 maxAmount;     // Permit2 witness cap
}

struct Output {
  address tokenOut;
  uint256 minAmount;     // user limit
}

struct Order {
  Input     baseInput;
  Output    baseOutput;
  address   swapper;
  address   reactor;       // target contract
  uint64    deadline;      // absolute
  uint32    epoc;          // seconds; 0 = not TWAP
  uint256   triggerPrice;  // off-chain hint, 0 if unused
  address   onlyDex;       // 0 = any; else required router/RFQ peer
  address   cosigner;      // oracle key
  bytes32   salt;          // uniqueness
}
```

`orderHash = keccak256(abi.encode(order))`
`swapperSig = ECDSA(orderHash)`

### 2.2 CosignerData (single oracle, v1)

```solidity
struct CosignerData {
  uint64  sigDeadline;
  uint16  exclusivityOverrideBps;
  address exclusiveFiller;      // optional allow-list
  uint256 inputAmountOverride;  // 0 = ignore
  uint256 outputAmountOverride; // 0 = ignore
  address[] payoutRecipients;   // optional extra payouts
  uint256[] payoutAmounts;      // 1-to-1 with recipients
}
digest     = keccak256(orderHash, keccak256(abi.encode(cosignerData)));
oracleSig  = ECDSA(digest);
```

*Every non-zero override may **only improve** the swapper’s terms.*

---

## 3 Reactor – `fill()` API

```solidity
function fill(
  Order          calldata order,
  CosignerData   calldata cd,
  bytes          calldata oracleSig,
  bytes          calldata liquidityCalldata   // router bytes or RFQ quote
) external;
```

*Key checks: swapper sig → oracle sig → deadlines → optional `onlyDex` → TWAP epoc guard → token transfer (Permit2) → swap execution. Overrides that worsen the order revert.*

---

## 4 Vault REST

| Route             | Purpose                                           |
| ----------------- | ------------------------------------------------- |
| `POST /order`     | `{ order, swapperSig }`                           |
| `POST /cancel`    | `{ orderHash }`                                   |
| `GET  /order/:id` | Public read                                       |
| `GET  /open`      | Filter by `chainId, dex, status=open, epocWindow` |
| `POST /oracleSig` | `{ orderHash, cosignerData, oracleSig }`          |

Public routes hide others’ orders; Executors use API-key routes.

---

## 5 Executor Flow

1. Poll `GET /open`.
2. Request `/oracleSig` for each candidate.
3. Simulate liquidity on `onlyDex` (or any router if 0).
4. Build `liquidityCalldata`; call `fill()`.
5. Update order status in Vault.

---

## 6 Oracle Flow

*HTTP endpoint*
`POST /quote { orderHash, ttl }` → returns `{ cosignerData, oracleSig }`.
Oracle signs only on request; no polling.

---

## 7 Roadmap

| Phase    | Upgrade                                                                                        |
| -------- | ---------------------------------------------------------------------------------------------- |
| **v1**   | This spec: single oracle, Permit2.                                                             |
| **v1.1** | Add SGX attestation field in `CosignerData`.                                                   |
| **v2**   | Replace EOA oracle with `ThresholdSigner` (BLS aggregate, multi-oracle).                       |
| **v3**   | Gas-sponsored swapper via AUTH (EIP-3074) or ERC-4337; on-chain median for stop-loss triggers. |

This README is now terminology-consistent (**Vault** replaces Lens/OrderHub) and ready as the starting brief for both contracts and off-chain services.
