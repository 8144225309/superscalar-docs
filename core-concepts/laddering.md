# Laddering

> **TLDR**: Instead of one giant factory, the LSP runs ~33 factories at once with staggered lifetimes. Each day, one factory dies and a new one is born. Users migrate during a 3-day window. This spreads the on-chain footprint to roughly 1 transaction per day.

## The Problem

A single factory has a **fixed lifetime** — its [[the-odometer-counter|DW counter]] will eventually run out, and its [[timeout-sig-trees|CLTV timeout]] will eventually expire. When a factory ends, everyone needs to move their funds somewhere. If all users exit at once, that's a massive spike of on-chain transactions.

## The Solution: Stagger Everything

```mermaid
gantt
    title Factory Laddering (simplified, 7-day example)
    dateFormat  YYYY-MM-DD
    axisFormat  %d

    section Factory 1
    Active     :f1a, 2025-01-01, 7d
    Dying      :f1d, after f1a, 3d

    section Factory 2
    Active     :f2a, 2025-01-02, 7d
    Dying      :f2d, after f2a, 3d

    section Factory 3
    Active     :f3a, 2025-01-03, 7d
    Dying      :f3d, after f3a, 3d

    section Factory 4
    Active     :f4a, 2025-01-04, 7d
    Dying      :f4d, after f4a, 3d

    section Factory 5
    Active     :f5a, 2025-01-05, 7d
    Dying      :f5d, after f5a, 3d
```

In reality, the parameters are:

| Parameter | Value |
|-----------|-------|
| Active period | ~30 days |
| Dying period | 3 days |
| Concurrent factories | ~33 |
| On-chain transactions per day (ideal) | 1 |

## How It Works

### The Lifecycle of a Single Factory

```mermaid
graph LR
    B["🔨 Born<br/>Day 1"] --> A["⚡ Active<br/>Days 1-30"]
    A --> D["💀 Dying<br/>Days 31-33"]
    D --> G["⚰️ Gone<br/>Day 34+"]

    style B fill:#51cf66,color:#fff
    style A fill:#4c6ef5,color:#fff
    style D fill:#ff922b,color:#fff
    style G fill:#868e96,color:#fff
```

**Born**: The LSP creates the factory — constructs the tree, signs all transactions with participating clients, publishes the funding UTXO on-chain.

**Active** (30 days): Normal operation. Clients have Lightning channels inside the factory. Payments flow normally. The LSP can sell inbound liquidity. State updates consume [[the-odometer-counter|odometer]] ticks.

**Dying** (3 days): The factory is winding down. Clients receive push notifications and should come online to migrate their funds to a new factory. The LSP creates a new factory using funds from the dying one.

**Gone**: The factory's CLTV timeout approaches. Any client that didn't migrate must [[force-close]].

### The Daily Rhythm

With 33 concurrent factories:

```
Day 1:   Factory #1 enters dying period → Factory #34 is born
Day 2:   Factory #2 enters dying period → Factory #35 is born
Day 3:   Factory #3 enters dying period → Factory #36 is born
...
Day 33:  Factory #33 enters dying period → Factory #66 is born
Day 34:  Factory #1 is gone; Factory #34 enters dying period → Factory #67 is born
```

**Ideally**, each day the LSP performs ONE on-chain transaction: the funding transaction for the new factory, which is funded by the cooperatively-closed old factory.

## Client Migration

When a factory enters its dying period, clients need to move their funds:

```mermaid
flowchart TD
    N["📱 Push notification:<br/>Your factory is dying!"]
    N --> O{"Client comes<br/>online?"}
    O -->|"Yes (within 3 days)"| M["Migrate funds"]
    O -->|"No"| F["Must force-close ⚠️"]

    M --> LN["Option 1:<br/>Normal LN payment<br/>to new factory channel"]
    M --> SWAP["Option 2:<br/>Offchain-to-onchain swap"]
    M --> PTLC["Option 3:<br/>PTLC assisted exit<br/>(private key handover)"]
```

### Option 1: Normal Lightning Payment
The simplest path. The client's old channel pays the client's new channel via a standard Lightning payment through the LSP. No extra on-chain footprint.

### Option 2: Offchain-to-Onchain Swap
The client receives their funds on-chain. More expensive (on-chain transaction) but gives the client a real UTXO they fully own.

### Option 3: PTLC Assisted Exit
The most elegant option. The client hands over their private key for the old factory (via a PTLC) and receives funds on-chain or in a new factory. The LSP can then sign as the departed client for the rest of the old factory's lifetime — simplifying cleanup.

## The Economic Beauty

```mermaid
graph TD
    subgraph "Without Laddering"
        W1["Day 30: ALL clients exit at once"]
        W1 --> W2["💥 Massive on-chain spike<br/>Hundreds of transactions"]
    end

    subgraph "With Laddering"
        L1["Day 1: ~3% of clients migrate"]
        L2["Day 2: ~3% of clients migrate"]
        L3["Day 3: ~3% of clients migrate"]
        L1 --> LS["📊 Smooth, predictable<br/>~1 tx/day ideal"]
        L2 --> LS
        L3 --> LS
    end
```

Laddering transforms a **catastrophic spike** into a **smooth daily drumbeat**. The LSP's on-chain footprint becomes predictable and minimal.

## The CLTV Timeout Formula

Each factory's absolute CLTV timeout must account for:

```
CLTV timeout = active_period + dying_period + max_DW_delay + safety_margin
             = 30 days      + 3 days       + ~6 days      + buffer
             ≈ 40 days
```

The `max_DW_delay` comes from the worst-case [[decker-wattenhofer-invalidation|DW]] force-close path. If two DW layers each have a max 432-block delay, that's ~6 days. The CLTV timeout must be far enough in the future that even a worst-case unilateral exit completes before the LSP's timeout path activates.

## What If a Client Never Comes Online?

If a client misses the 3-day dying period AND never comes back:

1. Their channel in the old factory eventually hits the CLTV timeout
2. The LSP can recover its own funds via the [[timeout-sig-trees|timeout script path]]
3. The client's funds remain spendable on-chain via the pre-signed exit transactions
4. With the **inverted timelock** design, a pre-signed nLockTime'd transaction distributes funds to clients automatically

The client's funds are never lost — but they may end up on-chain as small UTXOs, which the client would need to claim.

## What CTV Would Improve

One limitation today: when the LSP creates a new factory, ALL the clients joining it must be online to participate in the MuSig2 signing ceremony. With OP_CHECKTEMPLATEVERIFY (CTV, a proposed soft fork):

> The LSP could preemptively add clients to new factories without their participation. Clients would only need to come online during the dying period to claim their spot.

This would make the migration process much smoother, but CTV is not yet activated on Bitcoin.

## Related Concepts

- [[the-odometer-counter]] — Why factories have finite lifetimes
- [[timeout-sig-trees]] — The CLTV timeout that defines factory death
- [[client-migration]] — Detailed walkthrough of the migration process
- [[cooperative-close]] — How factories close cleanly
- [[force-close]] — What happens when migration fails
- [[soft-fork-landscape]] — How CTV would improve laddering
