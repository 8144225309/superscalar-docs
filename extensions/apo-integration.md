# APO Integration (SIGHASH_ANYPREVOUT)

BIP-118 introduces `SIGHASH_ANYPREVOUT` (APO) — a new signature hash type that omits the specific UTXO being spent from the signed digest. This enables **eltoo/LN-Symmetry**: any newer state transaction can replace any older one without requiring punishment or revocation.

For SuperScalar, APO would **replace the Decker-Wattenhofer invalidation layer** with eltoo, eliminating the finite state counter. The rest of the design — timeout-sig-trees, laddering, tree topology, client migration — remains unchanged.

---

## What APO Replaces

SuperScalar today uses DW invalidation: a decrementing `nSequence` counter across multiple layers that limits how many state updates a factory can hold. Each layer consumes part of the budget. When the counter runs out, the factory must rotate.

With APO, this entire mechanism is replaced by eltoo semantics: any newer state transaction can immediately supersede any older one, because its APO signature doesn't commit to which specific output it spends. The factory can hold **unlimited state updates**.

```
Without APO — Decker-Wattenhofer:
  States are finite (K^N where K = states per layer, N = layers)
  Older states are invalidated by the nSequence race
  Factory must rotate when the counter is exhausted

With APO — eltoo/LN-Symmetry:
  States are unlimited
  Any newer state directly supersedes any older state
  Rotation is driven by timeout expiry, not state exhaustion
```

---

## Specific Improvements

**Unlimited state updates**
The odometer counter constraint disappears. A factory can remain open indefinitely in principle, limited only by the timeout-sig-tree's CLTV budget — which is a separately tunable parameter.

**Simpler tree structure**
DW requires multiple layers to achieve a sufficient state count budget. With eltoo providing unlimited states, a single update layer is sufficient. The tree becomes shallower, reducing signing complexity and on-chain footprint during force-close.

**Shorter force-close times**
Fewer DW layers mean fewer stacked `nSequence` delays on the unilateral exit path. The worst-case time to recover funds decreases proportionally.

**No revocation data**
DW invalidation requires retaining the superseded state transactions (the decrementing-`nSequence` chain) for every prior epoch — note DW itself uses **no** revocation secrets; that absence is the whole distinction from Poon-Dryja. With eltoo, the LSP simply publishes the newest state and prior states need not be retained at all.

---

## What Does Not Change

APO replaces the state invalidation mechanism. Everything above and around it is unaffected:

| Component | Today | With APO |
|---|---|---|
| State invalidation | DW nSequence race | eltoo supersession |
| State count | Finite (K^N) | Unlimited |
| Timeout-sig-trees | Unchanged | Unchanged |
| Factory rotation (laddering) | On-chain tx required | **Still required** |
| Unilateral exit | Unchanged | Shorter (fewer layers) |
| MuSig2 signing | Unchanged | Unchanged |
| Tree topology | Unchanged | Simplified (fewer layers) |
| L-stock protection | Unchanged | Unchanged |

**Factory rotation still requires an on-chain transaction.** APO does not enable cooperative refresh of the factory on the same funding UTXO — the funding UTXO is consumed when the factory closes regardless. The laddering lifecycle (one new funding tx per rotation cycle) remains.

---

## Relationship to LN-Symmetry

LN-Symmetry (also called eltoo) is the Lightning-level protocol that APO enables. At the leaf channel level, LN-Symmetry replaces Poon-Dryja channels:

- No penalty transactions
- No per-update revocation secrets
- Any party can broadcast the latest state
- Simpler watchtower requirements

SuperScalar's leaf channels could adopt LN-Symmetry semantics if APO activates, independent of what happens at the factory layer above.

---

## Status

APO is specified in [BIP-118](https://github.com/bitcoin/bips/blob/master/bip-0118.mediawiki) and requires a soft fork. It is not activated on mainnet. The SuperScalar codebase isolates DW invalidation logic in `factory.c` and tapscript construction in `tapscript.c`, making an eventual APO-based redesign of the state invalidation layer tractable without touching the rest of the system.
