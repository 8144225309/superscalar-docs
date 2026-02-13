# Pseudo-Spilman Leaves

> **Summary**: An alternative leaf design that replaces one layer of Decker-Wattenhofer with a simpler unidirectional construct. Each "wide leaf" groups four clients under two pseudo-Spilman factories, reducing the total DW depth and shortening the CLTV delta imposed on public-network HTLCs.

## The Problem with Deep DW Trees

In the base SuperScalar design, every level of the [[factory-tree-topology|factory tree]] is a Decker-Wattenhofer layer. Each layer adds a relative timelock (via [[what-is-nsequence|nSequence]]) that accumulates from root to leaf. This total delay directly inflates the `min_final_cltv_expiry_delta` that clients must advertise on the public network.

For a 3-layer DW tree with ~3 days per layer, the total DW-imposed delay is ~9 days — consuming most of the typical 2-week CLTV budget and limiting the number of hops an HTLC can traverse before reaching the client.

## The Refinement: Wide Leaves

ZmnSCPxj proposed replacing the lowest DW layer with a **pseudo-Spilman channel factory** — a simpler construct that doesn't require decrementing nSequence timelocks.

In an arity-2 tree, each wide leaf contains:

- **4 clients** (instead of 2)
- **2 pseudo-Spilman factories** (each serving 2 clients + LSP)
- **1 fewer DW layer** than the base design

```mermaid
graph TD
    DW["DW State Node<br/>(one layer higher)"]

    DW --> PS1["Pseudo-Spilman Factory 1<br/>Clients A, B + LSP"]
    DW --> PS2["Pseudo-Spilman Factory 2<br/>Clients C, D + LSP"]

    PS1 --> CA["A ↔ LSP channel"]
    PS1 --> CB["B ↔ LSP channel"]
    PS1 --> L1["LSP liquidity stock"]

    PS2 --> CC["C ↔ LSP channel"]
    PS2 --> CD["D ↔ LSP channel"]
    PS2 --> L2["LSP liquidity stock"]
```

## What Is a Pseudo-Spilman Factory?

A standard Spilman channel is **unidirectional**: one party funds it, the other receives increasing payments over time. It terminates when the funder's balance reaches zero or a timeout expires.

The pseudo-Spilman variant adapts this for multi-party liquidity distribution:

1. The LSP starts with a liquidity stock allocation for a group of clients.
2. New states are **chained on top** of old states (appended, not replaced). Each state transaction spends the output of the previous one.
3. The LSP distributes liquidity to clients by signing new state transactions that increase client channel capacities and decrease the LSP's remaining stock.

```mermaid
graph LR
    S0["State 0<br/>LSP: 1.0 BTC<br/>A: 0, B: 0"] --> S1["State 1<br/>LSP: 0.7 BTC<br/>A: 0.3, B: 0"]
    S1 --> S2["State 2<br/>LSP: 0.4 BTC<br/>A: 0.3, B: 0.3"]
```

### Why "Pseudo"?

Unlike a true Spilman channel, the pseudo-Spilman doesn't rely on `nLockTime` for ordering. Instead, transactions are simply chained — state 1 spends state 0's output, state 2 spends state 1's output. Publishing state 0 forces state 1 to also be published (since state 1's input is state 0's output), and so on. The chain is self-ordering without requiring timelocks.

The trade-off: every state update adds another transaction to the unilateral-exit chain. If there have been K updates, force-close requires publishing K transactions for that leaf.

## How It Compares to Pure DW Leaves

| Property | DW at Leaves | Pseudo-Spilman at Leaves |
|----------|-------------|-------------------------|
| **DW layers removed** | 0 | 1 |
| **CLTV delta reduction** | — | ~3 days (one fewer nSequence layer) |
| **Clients per leaf** | 2 | 4 |
| **Signers for leaf update** | 3 (2 clients + LSP) | 3 (2 clients in one PS factory + LSP) |
| **Unilateral exit cost** | Fixed (one tx per DW layer) | Grows with updates (K txs per PS leaf) |
| **Direction** | Bidirectional (DW supports any reallocation) | Unidirectional (LSP → clients only) |

## The Trade-Off

Pseudo-Spilman leaves **reduce the CLTV delta** at the cost of **increased unilateral exit size** proportional to the number of leaf-level state updates. Since leaf updates are the most common operation (they require the fewest signers), this trade-off can result in longer on-chain transaction chains during force-close.

In practice, the number of leaf updates is bounded by the factory's lifetime — a 30-day factory with infrequent liquidity purchases may only accumulate a handful of pseudo-Spilman states.

## Old State Poisoning Protection

When the LSP signs a new pseudo-Spilman state, the old state's liquidity stock output must be protected against replay. The same [[shachain-revocation|shachain-based punishment]] used elsewhere in the factory applies here: clients hold a revealed secret for the old state and can burn the LSP's liquidity stock to miner fees if the LSP attempts to settle at an outdated state.

## When to Use Which Design

The choice between pure DW leaves and pseudo-Spilman leaves depends on deployment priorities:

- **CLTV budget is tight** (many routing hops needed) → pseudo-Spilman leaves
- **Minimal force-close footprint** is the priority → pure DW leaves
- **Leaf updates are infrequent** (clients rarely buy liquidity) → pseudo-Spilman is cheap
- **Leaf updates are frequent** (active liquidity market) → pure DW leaves avoid chain growth

ZmnSCPxj presented pseudo-Spilman leaves as a refinement for mobile-first deployments where the CLTV delta reduction matters more than worst-case force-close size.

## Current Status

- **Proposed**: By ZmnSCPxj on Delving Bitcoin (November 4, 2024)
- **Implemented**: Nowhere — no public code exists
- **Depends on**: Base SuperScalar factory implementation

## Related Concepts

- [[factory-tree-topology]] — The tree structure that pseudo-Spilman leaves modify
- [[decker-wattenhofer-invalidation]] — The mechanism pseudo-Spilman replaces at leaves
- [[shachain-revocation]] — Old state protection for pseudo-Spilman states
- [[the-odometer-counter]] — DW state counting that pseudo-Spilman leaves bypass
- [[force-close]] — How unilateral exit changes with chained pseudo-Spilman transactions
