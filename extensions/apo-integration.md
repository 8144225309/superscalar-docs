# APO Integration (SIGHASH_ANYPREVOUT)

BIP-118 introduces `SIGHASH_ANYPREVOUT` (APO) — a new signature hash type that omits the specific UTXO being spent from the signed digest. This unlocks a mechanism that doesn't exist in Bitcoin today: **invalidating a previously signed transaction by superseding it with a newer one, without touching the funding UTXO**.

For SuperScalar, APO's primary benefit is **cooperative factory refresh** — rotating the off-chain state tree without posting any on-chain transaction.

---

## The Problem APO Solves

Today, factory rotation requires an on-chain transaction because there is no way to invalidate a prior kickoff transaction. Two signed kickoff transactions spending the same funding UTXO are both valid indefinitely; Bitcoin has no ordering mechanism between them.

With APO, this changes. An APO-signed transaction does not commit to the `txid` of its input — only to the script and amount. This enables an **eltoo-style update mechanism**: a newer kickoff can be constructed to spend *either* the funding UTXO *or* the output of any prior kickoff. Publishing old state creates a spendable output; the LSP immediately sweeps it with the newer kickoff.

---

## How Cooperative Refresh Works with APO

```
Today (on-chain rotation required):
  Funding UTXO → Kickoff v1 (nSequence fixed)
  Funding UTXO → Kickoff v2 (same UTXO — no ordering possible)

With APO (cooperative refresh):
  Funding UTXO  ─────────────────────────────→ Kickoff v2 (APO)
                         ↓ (if v1 published)
                    Kickoff v1 output → Kickoff v2 (rebinds via APO)
```

**Rotation flow:**

1. All clients are online (asynchronously, via nonce pools — same as today)
2. LSP builds factory v2 tree with updated balances and a new epoch timeout
3. Kickoff v2 is signed with `SIGHASH_ANYPREVOUT` — it can spend any UTXO matching the funding script
4. Factory v1 pre-signed transactions become economically irrational to publish: if the kickoff v1 is broadcast, kickoff v2 immediately consumes it before any DW timeout expires
5. Funding UTXO remains on-chain, untouched, across multiple factory generations

**Result:** unlimited off-chain factory lifetimes. The funding UTXO persists indefinitely; on-chain transactions only appear when a client actually exits the factory.

---

## What Does Not Change

APO is additive. The entire DW invalidation stack, tree topology, MuSig2 signing architecture, and L-stock protection are unaffected. The only change is in kickoff transaction signature construction:

| Component | Today | With APO |
|---|---|---|
| Kickoff sighash | `SIGHASH_ALL` | `SIGHASH_ANYPREVOUT` |
| Factory rotation | New on-chain funding tx | Cooperative refresh (no on-chain tx) |
| Unilateral exit | Unchanged | Unchanged |
| DW invalidation | Unchanged | Unchanged |
| MuSig2 rounds | Unchanged | Unchanged |
| L-stock revocation | Unchanged | Unchanged |

---

## Fee Efficiency

Without APO, a laddered SuperScalar deployment posts roughly one on-chain transaction per active factory per rotation cycle. With APO, that drops to zero for cooperative rotations — on-chain transactions occur only when clients enter or exit.

For an LSP serving thousands of clients across many factories, this is a substantial fee reduction. The on-chain footprint becomes proportional to client churn rather than calendar time.

---

## Status

APO is specified in [BIP-118](https://github.com/bitcoin/bips/blob/master/bip-0118.mediawiki) and requires a soft fork. It is not yet activated on mainnet. The SuperScalar codebase is structured to support APO as an additive upgrade: kickoff transaction construction is isolated in `factory.c` and tapscript construction in `tapscript.c`. No architectural changes are required.
