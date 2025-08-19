Spot — Limit, TWAP, Stop-Loss

Who It’s For

- 🧭 Product: ship price-target, time-sliced, and protective orders.
- 🤝 Biz dev: onboard MMs/venues with clear rev-share and attribution.
- 🧩 Integrators: EIP-712 orders, cosigned prices, drop-in executors.

What It Does

- 🎯 Limit: execute at or above a target output amount.
- ⏱️ TWAP: slice a total size into fixed “chunks” per epoch.
- 🛡️ Stop: block execution when a signed-price breaches a trigger.

Why It Wins

- ✅ Non-custodial: per-order allowances via RePermit (witness-bound).
- 🔒 Safety: cosigned price, slippage caps, deadlines, epoch gating.
- ⚙️ Pluggable: inlined reactor + custom executors.
- 📈 Revenue: referral share + surplus distribution built in.

Architecture (At a Glance)

- 🧠 Reactor (`OrderReactor`): validates order, checks epoch, computes min-out from cosigned price, settles via inlined implementation.
- ✍️ RePermit (`RePermit`): Permit2-style EIP-712 with witness tying spend to the exact order hash.
- 🧾 Cosigner: signs current input/output price; freshness enforced (1 min).
- 🛠️ Executors (`SwapExecutor`/`Executor`): whitelisted fillers run venue logic via Multicall, return outputs, handle surplus.
- 🔐 WM (`WM`): allowlist gate for executors/admin functions.
- 🏭 Refinery (`Refinery`): ops utility to batch and sweep balances by bps.

Flow (Plain English)

1) User signs one EIP-712 order (chunk, total, limit, stop, slippage, epoch, deadline).
2) Cosigner attests to price (input/output, decimals, timestamp, nonce=order hash).
3) Allowed executor runs a Multicall strategy and calls the reactor.
4) Reactor checks signatures, epoch window, slippage, limit/stop, then settles.
5) Outputs and surplus are distributed (swapper + optional ref share).

Order Model (Key Fields)

- Input.amount: per-fill “chunk”.
- Input.maxAmount: total size across fills (TWAP budget).
- Epoch: seconds between fills (0 = single-use).
- Output.amount: limit (minimum acceptable out after slippage).
- Output.maxAmount: stop trigger (revert if above; MaxUint = off).
- Slippage: bps applied to cosigned price to compute min-out.
- ExclusiveFiller + OverrideBps: optionally lock to one executor, with time-bounded override.

Supported Strategies

- Single-shot limit: `epoch=0`, `input.amount=total`, `output.amount=limit`.
- TWAP: `epoch>0`, choose `input.amount` chunk, `input.maxAmount` total.
- Stop-loss / take-profit: set `output.maxAmount` as trigger boundary.

Integration Checklist

- Define the order in backend (EIP-712 struct per `OrderLib`).
- Run a cosigner service that emits fresh EIP-712 price payloads.
- Allowlist executors in `WM`; wire venue logic via Multicall calls.
- Submit to reactor using `executeWithCallback`.

Security Model

- ⏳ Freshness: cosignatures expire after 1 minute.
- 📉 Slippage cap: orders with extreme slippage are rejected.
- ⏱️ Epoch: prevents early/duplicate fills within a window.
- 🔐 Allowlist: only approved executors/admins can act.

Limits & Defaults

- Max slippage: 50% (in bps).
- Cosign freshness: 60 seconds.
- Epoch=0 means single execution.

Repo Map

- `src/reactor`: Order validation, epoch/slippage/price resolution.
- `src/repermit`: Witnessed Permit2-style spending (EIP-712).
- `src/executor`: Multicall-based swap executors and callbacks.
- `src`: `WM.sol` (allowlist), `Refinery.sol` (ops tools).

Glossary

- Reactor: verifies orders and settles internally.
- Executor: runs swap strategy, returns outputs, manages surplus/refshare.
- Cosigner: price attester used to derive min-out.
- Epoch: time bucket controlling TWAP cadence.

