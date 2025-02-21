## LiquidityHub

Below is a **concise, high-level overview** of **StopLoss** design, intended for DEXs who want to integrate a “stop order” feature into their UI:

---

## 1. Core Idea

- **StopLoss** extends a **Reactor-based** architecture (similar to UniswapX) with a **committee cosignature** using **EIP-1271**.
- Users create an **off-chain signed order** specifying:
  1. **In-Token** and **Out-Token**  
  2. **Amount In**  
  3. **Optional Limit** (min out) => “Stop Limit” or “Stop Market”  
  4. **Trigger Amount Out** => The “stop” condition  
  5. Other parameters like deadline

- The **order** is signed with **Permit2** approval (EIP712), granting permission for the protocol to pull the user’s tokens when triggered, **but** it requires an **EIP-1271 cosigner signature** before any fill is valid.

---

## 2. Off-Chain Monitoring & Committee Approval

1. The **user** submits their stop order via the DEX UI; the order is broadcasted to **off-chain service** (“Orbs L3”).  
2. A **committee** of off-chain members (L3 participants) each monitor the market independently for each open order. 
3. **Once the stop price is reached**, a threshold of committee members collectively sign the same order off-chain.  
   - This effectively “cosigns” that the user’s trigger occurred.  

---

## 3. On-Chain Execution & MEV Competition

- Now that the order is valid, it will be executed by one of the L3 members **on-chain** in a **single transaction**.
- The Reactor logic enforces:
  1. **Permit2** to safely transfer the user’s tokens.
  2. **Order** parameters verification.
  3. **Exclusivity Override** so that even the unlikely possibility of collusion by malicious fillers can be outbid by other MEV participants, ensuring the user gets a near-fair fill.  

In short, **MEV bots or multiple fillers** compete to fill the triggered stop order, which typically **pushes the user’s execution price closer to fair market** (similar to a “best execution” race).

---

## 4. Why This Matters for DEX UIs

- **Automated Stop Orders**: Users can set **stop-loss** or **stop-limit** parameters directly in your DEX interface, confident it will auto-execute once off-chain watchers confirm the price trigger.  
- **No Extra On-Chain Steps**: Fills happen with one transaction after the threshold signature is collected—no repeated user confirmations.  
- **Fair Execution**: The Reactor’s logic mitigates front-running risks, helping the user capture a better price even in volatile conditions.  
- **Just in time** swap: Tokens remain in the user's wallet until the stop is triggered.
- **Permit2** standard: Gasless order creation once allowance is given.

Essentially, this **StopLoss** system is a drop-in “trigger + fill” solution. Users place a stop order on your DEX UI, a **committee** ensures it only fires when the user’s conditions are met, and the **reactor** handles on-chain fulfillment in a single atomic transaction—**streamlining** the entire stop order experience.
