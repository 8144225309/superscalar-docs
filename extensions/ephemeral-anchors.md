# Ephemeral Anchors & v3 Transactions

> **Summary**: Pay-to-Anchor (P2A) is the breakthrough that made SuperScalar practical. It lets anyone fee-bump a pre-signed factory transaction at broadcast time, solving the fundamental problem of multi-party off-chain protocols: you sign now, but you don't know what fees will cost later. All three components are deployed on Bitcoin mainnet today.

## Why This Matters

Multi-party off-chain protocols have a fundamental tension: transactions are signed **cooperatively** during factory construction, but they might not be **broadcast** until months later during a force-close. Before ephemeral anchors, every participant needed their own anchor output for fee-bumping, which bloated transactions and didn't scale. The alternative — baking fees in at signing time — meant guessing the future fee market.

P2A solves this cleanly: a single anyone-can-spend anchor output that lets **any party** attach a fee-bumping child transaction at broadcast time. ZmnSCPxj called this the breakthrough that made Decker-Wattenhofer practical:

> *"P2A handled the issues I had with Decker-Wattenhofer — in particular, the difficulty of having either exogenous fees (without P2A, you need every participant to have its own anchor output) or mutable endogenous fees."*

## The Three Components

All three are **live on Bitcoin mainnet**:

### 1. TRUC / v3 Transactions (Bitcoin Core 28.0, October 2024)

A new transaction version (`nVersion=3`) with mempool relay policy rules:
- Max 1 unconfirmed parent allowed
- Max 1 unconfirmed child allowed
- Size limits on the child transaction

These constraints prevent pinning attacks — where an adversary attaches a large, low-fee child to block your CPFP attempt.

### 2. Pay-to-Anchor (P2A) Outputs (Bitcoin Core 28.0, October 2024)

A standard **anyone-can-spend** anchor output: `OP_1 <0x4e73>`. Any party — the LSP, the client, or even a third-party fee-bumping service — can spend this output to attach a CPFP child transaction.

No more needing separate anchor outputs per participant. One P2A output, anyone can bump.

### 3. Ephemeral Dust Exemption (Bitcoin Core 29.0, April 2025)

Normally, outputs below the dust limit (~546 sats) are rejected by the mempool. The ephemeral dust rule exempts P2A outputs in v3 transactions — the anchor can carry **zero sats**.

This means the factory tree transaction itself pays zero fees. All fees come from the CPFP child at broadcast time, when the fee market is known.

## How It Works Together

```mermaid
graph TD
    subgraph "At Factory Construction (months before broadcast)"
        SIGN["Sign tree transactions<br/>nVersion=3, fee=0<br/>+ zero-value P2A anchor"]
    end

    subgraph "At Force-Close (fee market is known)"
        BC["Broadcast tree tx"] --> CPFP["Anyone creates child tx<br/>spending P2A anchor<br/>with market-rate fee"]
        CPFP --> CONFIRM["Transaction confirms<br/>at the right fee"]
    end

    SIGN -.->|"Months pass"| BC

    style CONFIRM fill:#3fb950,color:#000
```

## Why ZmnSCPxj Said This Was the Breakthrough

> *"P2A handled the issues I had with Decker-Wattenhofer — in particular, the difficulty of having either exogenous fees (without P2A, you need every participant to have its own anchor output) or mutable endogenous fees."*

Before P2A, multi-party fee-bumping was a major obstacle. Each participant needed their own anchor output (bloating the transaction), or fees had to be baked in at signing time (the guessing problem). P2A made Decker-Wattenhofer practical for the first time.

## Package Relay

Related to v3/TRUC: **package relay** lets you submit a parent and child transaction together to the mempool as a single unit. This is critical because a zero-fee parent transaction would normally be rejected — package relay evaluates the combined feerate of parent+child.

Deployed in Bitcoin Core 28.0 alongside TRUC.

## What Needs to Change in the Code

| Current | Target |
|---------|--------|
| `nVersion=2` in tx_builder.c | `nVersion=3` |
| `fee_per_tx = 500` in factory.c | `fee = 0` |
| No anchor outputs | Add P2A output to each tree transaction |
| No CPFP logic | Add child transaction builder for fee bumping |

## Related Concepts

- [[transaction-structure]] — Transaction format (design specification)
- [[force-close]] — When tree transactions actually get broadcast
- [[building-a-factory]] — When tree transactions get signed
- [[research-horizon]] — Other future improvements
