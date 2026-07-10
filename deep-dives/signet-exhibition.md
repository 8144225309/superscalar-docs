# SuperScalar on Signet: A Live Exhibition

> **Summary**: SuperScalar's mechanisms are not only described in these docs — they have been **run end-to-end on real signet**, and every step left an on-chain transaction you can inspect for yourself. This page walks each exhibit — unilateral exit with fee-bumping anchors, punishing a cheating LSP, laddering, a **127-client factory (the design maximum) carrying real Lightning payments**, and the ceremonies that close it — with the actual transaction IDs. It also records, honestly, the things that did *not* go to plan, because those are findings too.

All transactions below are on **signet**, built by SuperScalar **v0.2.0**. View any of them at `https://mempool.space/signet/tx/<txid>`.

## Why run it on-chain at all

A protocol write-up can hide a great deal. The point of this exercise was to force every claim onto a real chain. If the timeout tree force-closes, there is a real cascade of transactions. If a client punishes a cheating LSP, there is a real recourse transaction that moves real sats. If 128 participants agree to close a factory, there is exactly one real Schnorr signature spending one real UTXO. Nothing below is a mock or a unit test — it is the software driving a real Bitcoin network.

The exhibition also used a realistic setup where it mattered: real Lightning payments were routed in from an **unmodified, non-bLIP-56 CLN node** through a bridge, so the 127-client factory carried genuine off-chain traffic rather than synthetic balances.

---

## Exhibit 1 — Unilateral exit: force-close + keyless anchors + CPFP

A client can always leave without the LSP's cooperation by broadcasting the pre-signed timeout-tree transactions. Each such transaction carries a **keyless P2A (pay-to-anchor) output** (`51024e73`) so that *anyone* can fee-bump a stuck exit with a child transaction (CPFP) — important when many parties may be racing the same block space.

| height | txid | what it is |
|---|---|---|
| 312264 | `c7ad28fa…` | factory funding (250k sat) |
| 312265 | `bee9cbf5…` | anchored force-close |
| 312266 | `ecac2791…` | anchored force-close (second state) |
| 312267 | `4648fc2e…` | **CPFP child spending a P2A anchor** — the fee-bump, on-chain |

## Exhibit 2 — The legible cascade (N=8)

The same exit, shaped to be readable: an 8-client, arity-2 factory force-closes mid-schedule, producing the full cascade (kickoff → state → leaf → close). **Every node in the cascade carries its own P2A anchor.**

| height | txid | what it is |
|---|---|---|
| 312339 | `2d054df3…` | factory funding |
| 312340 | `2b10e8d1…` | force-close cascade node (P2A) |
| 312342 | `1d96af3a…` | force-close cascade node (P2A) |
| 312343 | `cba7274f…` | force-close cascade node (P2A) |
| 312345 | `b2f95397…` | force-close cascade node (P2A) |
| 312346 | `b2c97bbe…` | force-close cascade node (P2A) |

## Exhibit 3 — A single client forcing its way out

The minimal case: one client force-closing its own small factory, run at 1 sat/vB so the commitment-level anchor is enabled. Confirms the anchors re-enable at ≥1 sat/vB with no extra flag.

| height | txid | what it is |
|---|---|---|
| 312366 | `978f62f6…` | factory funding |
| 312367 | `1fbc8f2f…` | force-close node (P2A @ 1 sat/vB) |
| 312369 | `a28bb6f7…` | force-close / commitment node (P2A) |

## Exhibit 4 — Punishing a cheating LSP (the poison)

The headline security property. The LSP broadcasts a **stale, superseded sub-factory state** (an attempted theft). The client's recourse assembles the revealed-secret **poison** transaction, which redistributes the LSP's sales-stock to the clients as punishment. See [Detecting LSP Misbehavior](#deep-dives/lsp-misbehavior) for the detection layer that triggers this.

| height | txid | what it is |
|---|---|---|
| 312266 | `ae4e99a0…` | sub-factory funding (200k) |
| 312267 | `97ee1aa1…` | tree node 0 |
| 312268 | `577d7e32…` | tree node 1 |
| 312269 | `e82035f2…` | **LSP cheat** — broadcasts a stale/superseded sub-state |
| 312272 | `d2ae19cf…` | **poison recourse** — 2-way redistribution, 21,085 sats to clients |

## Exhibit 5 — Laddering: rolling a factory to a new epoch

A live factory does not have to force-close to be refreshed. When clients cooperate, the LSP **rotates** the factory: it closes the old epoch and funds a new one on-chain, extending the useful life without a mass exit.

| height | txid | what it is |
|---|---|---|
| 312374 | `14900ae8…` | factory funding |
| 312379 | `d766282…` | old-epoch on-chain close (rotation step 1) |
| 312385 | `09762ddd…` | new-epoch funding (rotation complete) |

## Exhibit 6 — The 127-client factory, with real payments

The flagship. One LSP plus **127 clients** — the design maximum (128 signers, tree depth 7) — behind a single P2TR UTXO, with **no free sats**: clients start empty and earn balance from real inbound Lightning payments routed through the bridge from a vanilla CLN node.

| height | txid | what it is |
|---|---|---|
| 312349 | `143471b5…` | **127-client factory funding**, then **99 real routed payments** over a ~24 h soak |

The payments settle off-chain as Lightning HTLCs, so the factory's on-chain footprint is the funding plus its eventual close — but the traffic in between was real.

## Exhibit 7 — Closing the design-max factory in one signature

To close the 127-client factory, all 128 participants agree to spend the funding output. On-chain, that agreement is **a single transaction with one Schnorr signature that aggregates all 128 keys** — MuSig2 at the design maximum, on a real chain.

| height | txid | what it is |
|---|---|---|
| 312535 | `0ca6b929…` | **128-of-128 MuSig aggregate key-path spend** of the factory funding (162 bytes) |

This is the on-chain shape of a cooperative close, and it is arguably the strongest single artifact in the set: one signature, 128 signers, one UTXO.

## Exhibit 8 — Graceful end-of-life: rotation into a cooperative close

When a factory reaches the end of its schedule and its clients are online, the LSP's preferred path is not a force-close but a **cooperative** one: a key turnover followed by a clean close. Here an 8-client factory reaches its dying window and closes with **all 8 clients cooperating**.

| height | txid | what it is |
|---|---|---|
| 312532 | `6aa35632…` | factory funding (N=8) |
| 312543 | `c116878…` | **clean cooperative close via rotation — 8/8 clients cooperated** |

## Exhibit 9 — The timelock, proven by block heights

The timeout-tree leaves are timelock-gated (144-block CSV). Rather than a separate transaction, the proof is the **confirmation-height delta**: an output created at height *H* cannot be spent until *H + 144*, and stays unspent through the whole window.

- B-legible cascade: base **312339** → outputs unspendable until **312483**.
- 1-client commitment (`a28bb6f7…`): base **312369**, its outputs CSV-locked, unspent through the window, spendable only at **312510**.

Anyone can verify this on-chain with no cooperation from us.

---

## Honest findings

The exhibition is deliberately not airbrushed. Three things are worth stating plainly, because they are real properties of the system, not blemishes to hide:

- **A cooperative close at N=127 is a liveness bet.** The 24-hour soak lost roughly a quarter of its client daemons to ordinary attrition (running 127 daemons on one modest host is demanding). A cooperative close is N-of-N — it needs *every* participant — so it correctly could not complete and **fell back to force-close**. This is the designed behavior, and a useful data point: very large factories pay a real liveness cost, which is exactly why the timeout-tree fallback exists. (The factory funds were then recovered via the 128-key aggregate spend in Exhibit 7.)
- **Distribution-at-expiry is a fallback, not the default.** When clients cooperate, a dying factory **rotates or cooperatively closes** (Exhibits 5 and 8) — the better outcome. A pre-signed distribution that fires purely on expiry is the safety net for when rotation *cannot* happen (clients gone), so with cooperative clients the LSP correctly prefers rotation.
- **Fees and timing.** Signet was congested during parts of this run, so low-fee transactions confirmed slowly. For the *cooperative* paths shown here this is harmless — their timing is relative, and a late confirmation simply shifts the schedule. Fee-adequacy only becomes security-critical on the **adversarial** recourse paths (a penalty or poison that must confirm before a timelock matures), which is treated separately in the [Security Model](#deep-dives/security-model) and network-economics work.

## Provenance and recovery

All runs used strong, per-run keys (never publicly-derivable weak keys), so every output is recoverable by its operator and none is left sweepable by outsiders. After the exhibition, the bridge channel was cooperatively closed and every factory-funding-root residual was swept back to a single wallet — the same MuSig reconstruction used for Exhibit 7's close doubles as the recovery path.
