# CTV Integration (OP_CHECKTEMPLATEVERIFY)

BIP-119 introduces `OP_CHECKTEMPLATEVERIFY` (CTV) — an opcode that constrains an output to only be spent by a transaction matching a pre-committed hash. For SuperScalar, CTV's primary benefit is **removing the coordination bottleneck at factory construction**: the LSP can pre-build a new factory without waiting for clients to be online, and clients can claim their spot later at any point during the dying period.

---

## The Problem CTV Solves

Building a SuperScalar factory today requires all participating clients to be online simultaneously (or nearly so) for the MuSig2 signing rounds. The LSP cannot broadcast the funding transaction until every client has signed every node in the tree. This creates a hard dependency: factory construction is gated on client availability.

In the [[laddering]] lifecycle, a new factory must be ready before the current one's dying period ends. If clients are slow or offline during this window, the LSP is blocked.

---

## How CTV Changes Factory Construction

With CTV, the LSP can commit to the factory tree structure in the funding transaction output without any client signatures on interior nodes. The tree topology is enforced by the CTV hash commitment itself — not by N-of-N multisig.

```
Without CTV (today):
  1. LSP builds tree structure
  2. All clients must sign every interior node (MuSig2, multiple rounds)
  3. Clients sign their leaf channels
  4. Funding tx broadcast

With CTV:
  1. LSP builds tree structure, hashes it → CTV commitment
  2. LSP broadcasts funding tx with CTV commitment in output script
  3. Clients come online at any point and sign only their leaf channels
  4. Factory is live once leaf channels are signed
```

Clients no longer need to be present at funding time. They claim their spot in the factory by signing their leaf channel during the dying period of the previous factory — at whatever time is convenient for them.

---

## Impact on Laddering

This is particularly valuable during factory rotation:

```
Today:
  Dying period begins → LSP must coordinate ALL clients to come online → Sign new factory → Deploy

With CTV:
  Dying period begins → LSP deploys CTV-committed factory immediately
  ↓
  Clients trickle online throughout dying period, sign their leaf channels
  ↓
  Factory is fully active without a hard coordination deadline
```

The dying period goes from a hard client-coordination deadline to a soft window where clients confirm their participation at leisure.

---

## What Does Not Change

CTV affects factory construction timing only. It does not change state update mechanics, exit paths, or rotation requirements:

| Component | Today | With CTV |
|---|---|---|
| Factory construction | All clients online simultaneously | LSP builds first, clients sign later |
| Interior node signing | N-of-N MuSig2 required | Eliminated (hash-enforced) |
| Leaf channel signing | N-of-N required | Unchanged |
| State update signing | N-of-N required | Unchanged |
| Factory rotation (laddering) | On-chain tx required | **Still required** |
| Unilateral exit | Unchanged | Unchanged |
| DW invalidation | Unchanged | Unchanged |

---

## CTV + APO Together

The two upgrades are complementary:

- **CTV** removes the client coordination requirement at factory open — LSP can pre-build without blocking on client availability
- **APO** replaces the DW state invalidation layer with eltoo — unlimited state updates, simpler tree structure, shorter force-close times

Combined, factory construction becomes LSP-driven and non-blocking, and state updates become unlimited. On-chain rotation (laddering) remains the model for factory lifecycle — covenants don't eliminate that requirement.

---

## Comparison to Ark

CTV benefits Ark more than it benefits SuperScalar. Ark's fundamental design requires covenant enforcement to be non-interactive — without CTV, Ark degrades to an interactive protocol with trust tradeoffs. For SuperScalar, CTV is an ergonomic improvement: factory construction becomes easier to coordinate, but SuperScalar works correctly today without it.

---

## Status

CTV is specified in [BIP-119](https://github.com/bitcoin/bips/blob/master/bip-0119.mediawiki) and requires a soft fork. It is not activated on mainnet. The SuperScalar codebase constructs tree nodes in `factory.c` (`build_subtree`) and tapscripts in `tapscript.c`. CTV support would add hash-commitment output construction for interior nodes; the leaf signing and state update logic is unaffected.
