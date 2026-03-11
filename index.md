# SuperScalar

> SuperScalar enables multiple users to share a single on-chain UTXO for non-custodial Lightning channel access without requiring consensus changes.

## Motivation

Each Lightning channel requires a dedicated on-chain UTXO, which is a bottleneck given Bitcoin's limited throughput (~7 tx/sec). Users with no on-chain Bitcoin cannot open channels independently.

## Overview

SuperScalar lets many users share a single on-chain UTXO through an off-chain factory tree, using pre-signed transaction trees and N-of-N multisig rather than covenant opcodes. One LSP (Lightning Service Provider) coordinates the factory.

```mermaid
graph TD
    A["Alice"] --> U["Shared UTXO"]
    B["Bob"] --> U
    C["Carol"] --> U
    D["Dave"] --> U
    LSP["LSP"] --> U
    U --> T["Factory Tree<br/>(off-chain structure)"]
    T --> CH["Individual Lightning channels<br/>at the leaves"]

    style U fill:#fab005,color:#000
    style T fill:#4c6ef5,color:#fff
```

**Properties:**

- **Shared UTXO**: Many users share one on-chain UTXO instead of each needing their own.
- **Non-custodial**: N-of-N multisig means no single party — including the LSP — can move funds alone.
- **Unilateral exit**: If the LSP disappears, every user can force-close on-chain without anyone's permission.
- **No on-chain Bitcoin required**: Users can be onboarded with zero existing funds. The LSP provides initial liquidity.
- **No consensus changes**: This works on Bitcoin **today**. No soft fork needed.

At the leaves of the factory tree, each user gets a standard Lightning channel (Poon-Dryja) with the LSP. The distinguishing property is that these channels are backed by a shared UTXO rather than individual ones.

## Key Mechanisms

SuperScalar combines three mechanisms:

1. **[[decker-wattenhofer-invalidation]]** — Decrementing relative timelocks ensure newer state transactions confirm before older ones during unilateral close
2. **[[timeout-sig-trees]]** — N-of-N multisig with CLTV timeout fallback so the LSP can recover capital if clients disappear
3. **[[laddering]]** — Multiple factories with staggered lifetimes spread the on-chain footprint to ~1 tx/day

## Reading Order

<details>
<summary><strong>Prerequisites</strong> — Primer on payment channels, Taproot, MuSig2, and timelocks</summary>

1. [[what-is-a-payment-channel]] — How two people share a UTXO
2. [[what-is-multisig]] — Requiring multiple keys to authorize a spend
3. [[what-is-taproot]] — Key-path and script-path spending for compact on-chain footprint
4. [[what-is-musig2]] — How N people produce one signature
5. [[what-is-nsequence]] — Relative timelocks used by Decker-Wattenhofer
6. [[what-is-an-lsp]] — The node that coordinates a factory

</details>

### Protocol Design
1. [[decker-wattenhofer-invalidation]] — The time-delay state machine
2. [[the-odometer-counter]] — How layers multiply state capacity
3. [[timeout-sig-trees]] — N-of-N signing with LSP timeout fallback
4. [[factory-tree-topology]] — The tree structure explained
5. [[kickoff-vs-state-nodes]] — Why the tree alternates node types
6. [[shachain-revocation]] — Secret-based penalty for stale LSP state broadcasts
7. [[laddering]] — Factory rotation and lifecycle

### Protocol Operations
1. [[building-a-factory]] — Step-by-step construction
2. [[updating-state]] — What happens when factory state changes
3. [[cooperative-close]] — The happy path
4. [[force-close]] — When someone disappears
5. [[client-migration]] — Moving between factories

### Technical Reference
- [[musig2-signing-rounds]] — The 2-round signing protocol
- [[tapscript-construction]] — Building Taproot script trees
- [[transaction-structure]] — Actual Bitcoin transaction format
- [[security-model]] — Trust assumptions and threat model

### Extensions
- [[pseudo-spilman-leaves]] — Wide leaves that reduce DW depth and CLTV delta
- [[splicing-integration]] — Resizing channels inside factories
- [[pluggable-factories]] — Plugging into existing LN software
- [[dual-state-management]] — Handling factory transitions safely
- [[jit-channel-fallbacks]] — On-chain safety net when factories can't help
- [[ephemeral-anchors]] — P2A outputs and fee management

### Research
- [[research-horizon]] — Nested MuSig2, async payments, factory watchtowers, PTLCs, FROST/VLS, and other technologies worth watching

---

## Implementation

A working prototype is available at [github.com/8144225309/SuperScalar](https://github.com/8144225309/SuperScalar).

| Component | Status |
|-----------|--------|
| Factory construction (N-of-N MuSig2 tree signing) | Working |
| Leaf Lightning channels (Poon-Dryja) with HTLC routing | Working |
| Force close / unilateral exit | Working |
| Shachain revocation (punishment for stale state) | Working |
| PTLC assisted exit (key turnover) | Working |
| Factory laddering with auto-rotation | Working |
| Watchtower (old-state monitoring + penalty broadcast) | Working |
| Sub-1-sat/vB fee support with automatic P2A anchor control | Working |

The implementation is written in C, with 461 tests (418 unit + 43 regtest) and CI on Linux, macOS, and ARM64. It links against `secp256k1-zkp` for MuSig2/Schnorr and `libsqlite3` for state persistence.

## Origin

SuperScalar was designed by **ZmnSCPxj** (funded by Spiral, Block's open-source arm) and published on [Delving Bitcoin](https://delvingbitcoin.org) in September 2024. The design combines ideas from Christian Decker & Roger Wattenhofer's 2015 paper on duplex micropayment channels with timeout trees and the MuSig2 signing protocol.

> *"The goal of SuperScalar is to be able to onboard people, possibly people who do not have an existing UTXO they can use to pay exogenous fees."* — ZmnSCPxj
