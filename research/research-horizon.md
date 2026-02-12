# Research Horizon

> **TLDR**: Technologies that don't exist in production yet but could meaningfully improve SuperScalar if and when they land. None of these are dependencies — SuperScalar works today without any of them.

## Nested MuSig2

**Paper**: "Nested MuSig: Secure Hierarchical Multi-Signatures" by Nadav Kohen (Chaincode Labs), February 2026. [ePrint 2026/223](https://eprint.iacr.org/2026/223)

### The Interactivity Problem

SuperScalar's biggest UX cost is **interactivity**. Every factory state update requires all N participants (clients + LSP) to be online simultaneously for a MuSig2 signing round. If one client's phone is off, that entire subtree is stuck.

```mermaid
graph TD
    S1["MuSig2 Session"]
    LSP1["LSP"]
    A1["Alice"]
    B1["Bob"]
    C1["Carol"]
    D1["Dave"]
    E1["Eve"]
    F1["Frank"]
    G1["Grace"]
    H1["Heidi"]

    S1 --- LSP1
    S1 --- A1
    S1 --- B1
    S1 --- C1
    S1 --- D1
    S1 --- E1
    S1 --- F1
    S1 --- G1
    S1 --- H1

    style S1 fill:#f85149,color:#fff
```

All 9 participants must be online at the same time. One offline user blocks the entire signing round.

### What Nested MuSig2 Would Change

The paper proves that **composing MuSig2 sessions hierarchically** (MuSig2-of-MuSig2) is cryptographically secure. This means subtrees of a factory could sign independently and their signatures could be composed.

```mermaid
graph TD
    TOP["Top-level MuSig2"]
    SUB1["Subtree MuSig2"]
    SUB2["Subtree MuSig2"]
    LSP1["LSP"]
    A2["Alice"]
    B2["Bob"]
    C2["Carol"]
    LSP2["LSP"]
    D2["Dave"]
    E2["Eve"]
    F2["Frank"]
    G2["Grace"]

    TOP --- SUB1
    TOP --- SUB2
    SUB1 --- LSP1
    SUB1 --- A2
    SUB1 --- B2
    SUB1 --- C2
    SUB2 --- LSP2
    SUB2 --- D2
    SUB2 --- E2
    SUB2 --- F2
    SUB2 --- G2

    style TOP fill:#3fb950,color:#000
    style SUB1 fill:#58a6ff,color:#000
    style SUB2 fill:#58a6ff,color:#000
```

Only the participants in an affected subtree need to be online. If Alice wants to update her channel, only Alice, Bob, Carol, and the LSP sign — Dave through Grace don't need to be awake.

### Why This Matters for Mobile Users

SuperScalar targets people in developing nations using mobile phones. These devices are intermittently connected — battery saving, spotty data, etc. Reducing the number of people who must be simultaneously online for any given update is a direct UX improvement.

| | Flat N-of-N (today) | Nested (future) |
|---|---|---|
| **Who signs** | All 9 participants | Only affected subtree (3-4 people) |
| **One phone offline** | Entire factory stuck | Only that subtree stuck |
| **Signing rounds** | 1 big round | Smaller independent rounds |

### Current Status

- **Paper**: Published, peer review ongoing
- **Library support**: None — secp256k1-zkp's MuSig2 module would need to be extended
- **Estimated timeline**: Unknown. Could be 6-12+ months before any library ships this
- **For SuperScalar**: Watch and wait. Don't build on it yet.

---

## Async Payments

### The Other Half of the Offline Problem

Nested MuSig2 helps with **signing** while some participants are offline. Async payments solve the other side: **receiving payments** while offline.

SuperScalar's target user has a phone that goes to sleep, loses signal, or runs out of battery. If someone sends them sats while they're unreachable, what happens?

```mermaid
sequenceDiagram
    participant S as Sender
    participant LSP as LSP
    participant R as Recipient

    S->>LSP: Pay 1000 sats to Recipient
    LSP->>LSP: Hold HTLC (Recipient offline)
    Note over R: Hours pass... Phone wakes up
    R->>LSP: I am back online
    LSP->>R: Forward held HTLC
    R->>LSP: Preimage (claim payment)
    LSP->>S: Payment complete
```

The LSP acts as a buffer, holding incoming payments until the recipient comes online. Since the HTLC has a timeout, the sender gets their money back if the recipient never wakes up.

### Active Spec Work

- **Trampoline routing**: Lets the LSP handle routing decisions, reducing what the mobile client needs to compute
- **Async invoice protocol**: Being discussed in the Lightning spec — standardizing how to pay someone who isn't online
- **BOLT 12 / Offers**: The new invoice format supports reusable payment codes, which pairs naturally with async delivery

### For SuperScalar

Factory-hosted channels are a natural fit for async payments. The LSP already manages the factory and has a persistent relationship with each client. It knows which clients are in which factory and can hold payments for offline participants without additional infrastructure.

### Current Status

- **Spec work**: Active discussion, no finalized standard
- **Implementations**: Some LSPs (like Phoenix/ACINQ) already do limited async holding
- **For SuperScalar**: Important for production UX, not needed for PoC

---

## Factory Watchtowers

### Why Factories Are Harder to Watch

Standard Lightning watchtowers have a simple job: watch for a single revoked commitment transaction and broadcast a penalty transaction if it appears.

Factory watchtowers are harder because there's a **tree** of transactions to monitor, not just one.

```mermaid
graph TD
    W1["Standard LN Watchtower"] --> R1["Watch for 1 thing:<br/>revoked commitment tx"]
    R1 --> P1["Broadcast penalty tx"]

    W2["Factory Watchtower"] --> R2["Watch for revoked state<br/>at ANY DW layer"]
    R2 --> L1["Layer 0: broadcast<br/>current kickoff + state"]
    R2 --> L2["Layer 1: broadcast<br/>current state at layer 1"]
    R2 --> L3["Layer 2: broadcast<br/>current state at layer 2"]
    L1 --> CH["Then watch for revoked<br/>channel commitments<br/>at leaf outputs"]
    L2 --> CH
    L3 --> CH

    style W1 fill:#58a6ff,color:#000
    style W2 fill:#d29922,color:#000
```

The watchtower needs to:
1. Recognize which DW layer a revoked state belongs to
2. Broadcast the correct current state for that layer
3. Handle the [[shachain-revocation]] punishment mechanism
4. Monitor leaf channel outputs for revoked commitments too
5. Manage fee-bumping for all these transactions

### The Storage Problem

For a factory with 3 DW layers and 4 states per layer (64 epochs), the watchtower needs to store response data for each possible revoked state across each layer. With 8 clients, that's a lot of pre-signed penalty data to hold.

### Current Status

- **Research**: No published protocol for factory-specific watchtowers
- **Standard LN watchtowers**: Exist (The Eye of Satoshi, LND's built-in) but only handle simple channels
- **For SuperScalar**: Important for production security, especially for mobile users who can't monitor the chain. Not needed for PoC (regtest can be monitored manually).

---

## PTLCs (Point Time-Locked Contracts)

### Beyond HTLCs

Current Lightning uses **HTLCs** (Hash Time-Locked Contracts) for routing payments: the sender locks funds with a hash, and the recipient unlocks them with the preimage. Every hop in the route uses the **same hash**, which is a privacy leak — any two colluding nodes can tell they're on the same payment route.

**PTLCs** replace the hash/preimage with **adaptor signatures** on elliptic curve points. Each hop uses a different point, breaking the correlation.

```mermaid
graph LR
    A1["Alice"] -->|"hash H"| B1["Bob"]
    B1 -->|"same hash H"| C1["Carol"]
    C1 -->|"same hash H"| D1["Dave"]

    A2["Alice "] -->|"point P1"| B2["Bob "]
    B2 -->|"point P2"| C2["Carol "]
    C2 -->|"point P3"| D2["Dave "]

    style A1 fill:#f85149,color:#fff
    style B1 fill:#f85149,color:#fff
    style C1 fill:#f85149,color:#fff
    style D1 fill:#f85149,color:#fff
    style A2 fill:#3fb950,color:#000
    style B2 fill:#3fb950,color:#000
    style C2 fill:#3fb950,color:#000
    style D2 fill:#3fb950,color:#000
```

**Red (top)**: HTLC — same hash H at every hop, linkable. **Green (bottom)**: PTLC — different point at every hop, unlinkable.

### Why This Matters for SuperScalar

SuperScalar already needs adaptor signatures for **PTLC key turnover** — the assisted exit mechanism where the client hands their factory signing key to the LSP in exchange for channel state in a new factory. The adaptor sig parameter exists in the codebase (`musig.c`) but is always passed as NULL.

PTLCs at the routing layer and PTLCs for key turnover use the same cryptographic primitive. Building one helps build the other.

### Current Status

- **Cryptography**: Well understood. Adaptor signatures on Schnorr are straightforward.
- **LN spec**: No timeline for PTLC adoption across the network
- **In SuperScalar code**: Adaptor sig parameter exists in MuSig2 API but unused
- **For SuperScalar**: Key turnover (Phase 4) needs this. General PTLC routing is a broader LN upgrade.

---

## A Note on FROST

**FROST** (Flexible Round-Optimized Schnorr Threshold signatures) enables t-of-n signing — for example, 5-of-9 instead of 9-of-9. It's worth knowing about, but it's **architecturally incompatible** with SuperScalar. The entire security model depends on n-of-n: every participant must sign, so no single party (including the LSP) can move funds alone. Switching to t-of-n means a colluding quorum could steal. Different trust model, different protocol.

## Related Concepts

- [[what-is-musig2]] — The signing protocol that nested MuSig2 extends
- [[musig2-signing-rounds]] — Current signing implementation details
- [[factory-tree-topology]] — The tree structure that nested signing would optimize
- [[soft-fork-landscape]] — Detailed analysis of each soft fork proposal
- [[security-model]] — Why n-of-n matters for the trust model
- [[ephemeral-anchors]] — The planned upgrade that's actually ready to implement now
