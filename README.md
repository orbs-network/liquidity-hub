Liquidity Hub — Limit, TWAP, Stop Orders on UniswapX

Who It’s For

- 🧭 Product: ship price-target, time-sliced, and protective orders.
- 🤝 Biz dev: onboard MMs/venues with clear rev-share and attribution.
- 🧩 Integrators: drop-in contracts, EIP-712, and simple scripts.

What It Does

- 🎯 Limit: execute at or above a target output amount.
- ⏱️ TWAP: slice a total amount into fixed “chunks” per epoch.
- 🛡️ Stop: block execution when a signed-price exceeds a trigger.

Why It Wins

- ✅ Non-custodial: user approvals scoped per order via RePermit.
- 🔒 Safety: signed price oracle (cosigner), slippage bounds, deadlines.
- ⚙️ Pluggable: works with UniswapX reactors and custom executors.
- 📈 Revenue-ready: referral share + surplus handling supported.

How It Works (Plain English)

- Users sign one EIP-712 order with: input chunk, total size, limit, stop, slippage, deadline.
- A price cosigner attests to current price (fresh within 1 minute).
- A whitelisted executor runs a strategy (multicall), fills, and reports back.
- The reactor checks signatures, TWAP epoch timing, slippage, limit/stop, then settles via UniswapX.

Order Model (Key Fields)

- Input.amount: per-fill “chunk”.
- Input.maxAmount: total size across fills (TWAP budget).
- Epoch: seconds between fills (0 = single use).
- Output.amount: limit (minimum acceptable out after slippage).
- Output.maxAmount: stop trigger (revert if exceeded; MaxUint = off).
- Slippage: bps applied to signed price to compute min-out.
- ExclusiveFiller: optional designated executor; override bps allows opt-out.

Main Components

- OrderReactor: validates orders, enforces epochs, computes out via signed price, and calls UniswapX.
- SwapExecutor / Executor: whitelisted fillers that run a multicall strategy and handle outputs/surplus.
- RePermit: compact EIP-712 permit with “witness” binding the order hash to spending.
- WM: simple allowlist to gate who can execute/admin.
- Refinery: ops tool to batch calls and sweep balances by bps to recipients.

Supported Flows

- Single-shot limit: set Epoch=0, Input.amount=total, Output.amount=limit.
- TWAP: set Epoch>0, choose Input.amount chunk, Input.maxAmount total.
- Stop-loss/take-profit: set Output.maxAmount to your trigger boundary.

Integration Checklist

- Define order fields in your backend or signer service.
- Run a cosigner that produces fresh price EIP-712 payloads.
- Whitelist your executors via WM; plug in your venue logic via multicall.
- Submit orders to the reactor using UniswapX’s executeWithCallback path.

Deploy Scripts (Foundry)

- 00_DeployWM.s.sol: create allowlist admin.
- 01_UpdateWMWhitelist.s.sol: batch allow/revoke executors.
- 02_DeployRepermit.s.sol: deploy RePermit (EIP-712 domain).
- 03_DeployReactor.s.sol: deploy OrderReactor with RePermit + cosigner.
- 04_DeployExecutor.s.sol: deploy generic Executor (or wire your own).

Run Locally

- Build/tests: `forge build`, `forge test -vvv`
- Gas: `forge snapshot` (see `.gas-snapshot`)

Safety & Controls

- CosignatureFreshness: 1 minute window for signed prices.
- Slippage cap: rejects orders with extreme slippage settings.
- Epoch enforcement: prevents early/duplicate fills within a window.
- Allowlist: only approved executors/admins can act.

Glossary

- Reactor: verifies orders and settles via UniswapX.
- Executor: address that runs the swap strategy and returns outputs.
- Cosigner: signs current price used to compute min-out.
- Epoch: time bucket controlling TWAP cadence.

Questions / Next Steps

- Want a venue/MM added, or branded executors and dashboards? Open an issue or reach out with target chains, venues, and referral terms.
