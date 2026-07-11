# SuperScalar on Signet: A Live Exhibition

> **Summary**: SuperScalar's mechanisms aren't only described in these docs — they've been **run end-to-end on real signet**, and every step left an on-chain transaction you can inspect for yourself. This page walks each exhibit — unilateral exit with fee-bumping anchors, punishing a cheating LSP, laddering, a **127-client factory (the design maximum) carrying real Lightning payments**, and the ceremonies that open and close it — with the actual transaction IDs. It also records, honestly, the things that did *not* go to plan, because those are findings too.

All transactions below are on **signet**, built by SuperScalar **v0.2.0**. **Every txid links to the live transaction on [mempool.space](https://mempool.space/signet)** — click any of them to inspect the real on-chain data.

## The exhibits at a glance

| # | Exhibit | on-chain proof | block(s) |
|---|---|---|---|
| 1 | Unilateral exit — force-close + keyless P2A anchors + CPFP | [`4648fc2e…`](https://mempool.space/signet/tx/4648fc2e7c122f227109eac285d804fa6d374832a7fabfb6e20359a7ae12d700) (CPFP child) | 312264–267 |
| 2 | The legible force-close cascade (N=8, five P2A nodes) | [`2d054df3…`](https://mempool.space/signet/tx/2d054df38cecbec834c5c1ac3640faa7f981f86bf75700262c0717c0724b1839) → cascade | 312339–346 |
| 3 | A single client forcing its way out (@ 1 sat/vB) | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) | 312366–369 |
| 4 | Punishing a cheating LSP — the revealed-secret poison | [`e82035f2…`](https://mempool.space/signet/tx/e82035f2b724c0c16225fada682af20684a91bc04aa62f59718a1a2e3c4a53a2) cheat → [`d2ae19cf…`](https://mempool.space/signet/tx/d2ae19cf39547b7eb69930ef8ad92e3d7f51e683b02cd8643a74d45640d4a4f0) poison | 312269–272 |
| 5 | Laddering — rotating a factory to a new epoch | [`d766282…`](https://mempool.space/signet/tx/d766282072e58b4ed4775cde9f71d97bea32dab1f8f5f95be931ffdb7ce382d5) → [`09762ddd…`](https://mempool.space/signet/tx/09762dddc6f977de0a94bc9d0f1ab670a419c6482a3b493b77c365f3e47cb980) | 312379–385 |
| 6 | The 127-client factory + 99 real Lightning payments | [`143471b5…`](https://mempool.space/signet/tx/143471b5d1ddc0eee3ea54d74ed17081f24d48f429bb826723c8b0897e55c0e6) | 312349 |
| 7 | Closing the design-max factory in one signature — 128-of-128 MuSig2 | [`0ca6b929…`](https://mempool.space/signet/tx/0ca6b929e2d7a52633b33d3a0a36f531d6230f49ffccbac7486977d745aa1056) | 312535 |
| 8 | Graceful end-of-life — rotation into a cooperative close (8/8) | [`c116878…`](https://mempool.space/signet/tx/c116878091ce0f5d5aa1b812edd119fd1408b9308579eda3ea2836ca687f3af7) | 312543 |
| 9 | The timelock, proven by block heights (144-block CSV) | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) (heights) | 312369 → 312510 |
| 10 | The Decker–Wattenhofer odometer — state checkpoints | [`6e3264f7…`](https://mempool.space/signet/tx/6e3264f7c2c8676e8eec757296e2463568655419a76f1a26b095abbf55bf5e08) | 312619 |
| 11 | Distribution at expiry — the offline-forever safety net | [`9f3e0829…`](https://mempool.space/signet/tx/9f3e082943b4133261525d6e98137317535365c8f49f0535c4ae059ac9050997) | 312660 |
| 12 | JIT channels — just-in-time inbound liquidity | [`6d580835…`](https://mempool.space/signet/tx/6d580835f2913e68924c943c73771893b8dc49e1844e3157663f7d87ce6f1988) | 312657 |

Twelve exhibits, one theme: **every mechanism in the protocol left a real transaction on a real chain.** The detailed walk-throughs follow, grouped roughly by a factory's life — exit, recourse, laddering, the flagship, close, and the safety nets.

## Why run it on-chain at all

A protocol write-up can hide a great deal; the point of this exercise was to force every claim onto a real chain. If the timeout tree force-closes, there is a real cascade of transactions. If a client punishes a cheating LSP, there is a real recourse transaction moving real sats. If 128 participants agree to close a factory, there is exactly one real Schnorr signature spending one real UTXO. Nothing below is a mock or a unit test — it is the software driving a real Bitcoin network.

Where it mattered, the setup was realistic too: real Lightning payments were routed in from an **unmodified, non-bLIP-56 CLN node** through a bridge, so the 127-client factory carried genuine off-chain traffic rather than synthetic balances.

---

## Exhibit 1 — Unilateral exit: force-close + keyless anchors + CPFP

A client can always leave without the LSP's cooperation by broadcasting the pre-signed timeout-tree transactions. Each carries a **keyless P2A (pay-to-anchor) output** (`51024e73`) so that *anyone* can fee-bump a stuck exit with a child transaction (CPFP) — important when many parties may be racing the same block space.

| height | txid | what it is |
|---|---|---|
| 312264 | [`c7ad28fa…`](https://mempool.space/signet/tx/c7ad28faecc4a754eb5e9f2bffd2430129d69b9c200c41a654ea56ebb1b09fac) | factory funding (250k sat) |
| 312265 | [`bee9cbf5…`](https://mempool.space/signet/tx/bee9cbf5c44ef951b521832a703c1ed34432878d080e0848534130b7aa9fa84a) | anchored force-close |
| 312266 | [`ecac2791…`](https://mempool.space/signet/tx/ecac2791a686e821c5ecb60560cbe8c62ebaca4bb99174c9f9caebcc7d3a6ab7) | anchored force-close (second state) |
| 312267 | [`4648fc2e…`](https://mempool.space/signet/tx/4648fc2e7c122f227109eac285d804fa6d374832a7fabfb6e20359a7ae12d700) | **CPFP child spending a P2A anchor** — the fee-bump, on-chain |

## Exhibit 2 — The legible cascade (N=8)

The same exit, shaped to be readable: an 8-client, arity-2 factory force-closes mid-schedule, producing the full cascade (kickoff → state → leaf → close). **Every node carries its own P2A anchor.**

| height | txid | what it is |
|---|---|---|
| 312339 | [`2d054df3…`](https://mempool.space/signet/tx/2d054df38cecbec834c5c1ac3640faa7f981f86bf75700262c0717c0724b1839) | factory funding |
| 312340 | [`2b10e8d1…`](https://mempool.space/signet/tx/2b10e8d168c1f5af7963284116f832a2526f8b8415a9d4ca83a671ee9ff49961) | force-close cascade node (P2A) |
| 312342 | [`1d96af3a…`](https://mempool.space/signet/tx/1d96af3add57e8507a92b56215eea004c29a4783545c40948fbaa92e1fcd77ed) | force-close cascade node (P2A) |
| 312343 | [`cba7274f…`](https://mempool.space/signet/tx/cba7274f26b6c88b08af84b9dfe71933da8e5d563404aa9520339e0992e68b05) | force-close cascade node (P2A) |
| 312345 | [`b2f95397…`](https://mempool.space/signet/tx/b2f953974b6f20438cd29e57d7f4da926f7ca3452034ad3e877afbd6d884dba7) | force-close cascade node (P2A) |
| 312346 | [`b2c97bbe…`](https://mempool.space/signet/tx/b2c97bbeb9f02bbecbed09c40ba6d4e65b8918b32e8d95baee3afb251ce342ed) | force-close cascade node (P2A) |

## Exhibit 3 — A single client forcing its way out

The minimal case: one client force-closing its own small factory at 1 sat/vB, which enables the commitment-level anchor. This confirms the anchors re-enable at ≥1 sat/vB with no extra flag.

| height | txid | what it is |
|---|---|---|
| 312366 | [`978f62f6…`](https://mempool.space/signet/tx/978f62f662eb1c8180f7c617b4e7ef6a1d30eaf8fb3fb281cc21550a03fdd053) | factory funding |
| 312367 | [`1fbc8f2f…`](https://mempool.space/signet/tx/1fbc8f2f7b1fcf470a239c6c8f0f88ef6ab5794c226eb554e17b67b023be1ee4) | force-close node (P2A @ 1 sat/vB) |
| 312369 | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) | force-close / commitment node (P2A) |

## Exhibit 4 — Punishing a cheating LSP (the poison)

The headline security property. The LSP broadcasts a **stale, superseded sub-factory state** — an attempted theft. The client's recourse assembles the revealed-secret **poison** transaction, which redistributes the LSP's sales-stock to the clients as punishment. See [Detecting LSP Misbehavior](#deep-dives/lsp-misbehavior) for the detection layer that triggers this.

| height | txid | what it is |
|---|---|---|
| 312266 | [`ae4e99a0…`](https://mempool.space/signet/tx/ae4e99a0601fd9db4fc26ee02ae928d1793ee770fbadd5741f5de25391705b4a) | sub-factory funding (200k) |
| 312267 | [`97ee1aa1…`](https://mempool.space/signet/tx/97ee1aa1e37f17dc3a315b63fab2aa78556d086cb0f624b0cfa6c932c8d09e49) | tree node 0 |
| 312268 | [`577d7e32…`](https://mempool.space/signet/tx/577d7e32da5a6b82c83ebbead50fbef0294a9d74154780203473b609ba53eaf0) | tree node 1 |
| 312269 | [`e82035f2…`](https://mempool.space/signet/tx/e82035f2b724c0c16225fada682af20684a91bc04aa62f59718a1a2e3c4a53a2) | **LSP cheat** — broadcasts a stale/superseded sub-state |
| 312272 | [`d2ae19cf…`](https://mempool.space/signet/tx/d2ae19cf39547b7eb69930ef8ad92e3d7f51e683b02cd8643a74d45640d4a4f0) | **poison recourse** — 2-way redistribution, 21,085 sats to clients |

## Exhibit 5 — Laddering: rolling a factory to a new epoch

A live factory doesn't have to force-close to be refreshed. When clients cooperate, the LSP **rotates** it: close the old epoch and fund a new one on-chain, extending the useful life without a mass exit.

| height | txid | what it is |
|---|---|---|
| 312374 | [`14900ae8…`](https://mempool.space/signet/tx/14900ae867a7f34f2d9390e74b2c0af801cb8467f16bf31cf2cf9eb5fb6b8dbf) | factory funding |
| 312379 | [`d766282…`](https://mempool.space/signet/tx/d766282072e58b4ed4775cde9f71d97bea32dab1f8f5f95be931ffdb7ce382d5) | old-epoch on-chain close (rotation step 1) |
| 312385 | [`09762ddd…`](https://mempool.space/signet/tx/09762dddc6f977de0a94bc9d0f1ab670a419c6482a3b493b77c365f3e47cb980) | new-epoch funding (rotation complete) |

## Exhibit 6 — The 127-client factory, with real payments

The flagship. One LSP plus **127 clients** — the design maximum (128 signers, tree depth 7) — behind a single P2TR UTXO, with **no free sats**: clients start empty and earn balance from real inbound Lightning payments routed through the bridge from a vanilla CLN node.

| height | txid | what it is |
|---|---|---|
| 312349 | [`143471b5…`](https://mempool.space/signet/tx/143471b5d1ddc0eee3ea54d74ed17081f24d48f429bb826723c8b0897e55c0e6) | **127-client factory funding**, then **99 real routed payments** over a ~24 h soak |

The payments settle off-chain as Lightning HTLCs, so the factory's on-chain footprint is the funding plus its eventual close — but the traffic in between was real.

## Exhibit 7 — Closing the design-max factory in one signature

To close the 127-client factory, all 128 participants agree to spend the funding output. On-chain, that agreement is **a single transaction with one Schnorr signature aggregating all 128 keys** — MuSig2 at the design maximum, on a real chain.

| height | txid | what it is |
|---|---|---|
| 312535 | [`0ca6b929…`](https://mempool.space/signet/tx/0ca6b929e2d7a52633b33d3a0a36f531d6230f49ffccbac7486977d745aa1056) | **128-of-128 MuSig aggregate key-path spend** of the factory funding (162 bytes) |

This is the on-chain shape of a cooperative close, and arguably the strongest single artifact in the set: one signature, 128 signers, one UTXO.

## Exhibit 8 — Graceful end-of-life: rotation into a cooperative close

When a factory reaches the end of its schedule and its clients are online, the LSP's preferred path is not a force-close but a **cooperative** one: a key turnover followed by a clean close. Here an 8-client factory reaches its dying window and closes with **all 8 clients cooperating**.

| height | txid | what it is |
|---|---|---|
| 312532 | [`6aa35632…`](https://mempool.space/signet/tx/6aa35632cbeedeb5a92c22d30de962f8ad4cdcb8c8c335f693790766cab6203c) | factory funding (N=8) |
| 312543 | [`c116878…`](https://mempool.space/signet/tx/c116878091ce0f5d5aa1b812edd119fd1408b9308579eda3ea2836ca687f3af7) | **clean cooperative close via rotation — 8/8 clients cooperated** |

## Exhibit 9 — The timelock, proven by block heights

The timeout-tree leaves are timelock-gated (144-block CSV). Rather than a separate transaction, the proof is the **confirmation-height delta**: an output created at height *H* cannot be spent until *H + 144*, and stays unspent through the whole window.

- B-legible cascade: base **312339** → outputs unspendable until **312483**.
- 1-client commitment ([`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223)): base **312369**, its outputs CSV-locked and unspent through the window, spendable only at **312510**.

Anyone can verify this on-chain with no cooperation from us.

## Exhibit 10 — The Decker-Wattenhofer odometer (state checkpoints)

Inside a factory, balances are updated **off-chain** by re-signing the state tree. Each update **decrements the state's relative-timelock (nSequence)** — the "odometer" — so a newer state can always be published ahead of a stale one, which is how old states are invalidated. Here a factory advanced its DW counter and the state nodes' nSequence stepped **down** on-chain:

```
Node 3: nSequence 0x32 (50) → 0x1E (30)
Node 5: nSequence 0x32 (50) → 0x1E (30)
```

| height | txid | what it is |
|---|---|---|
| 312619 | [`6e3264f7…`](https://mempool.space/signet/tx/6e3264f7c2c8676e8eec757296e2463568655419a76f1a26b095abbf55bf5e08) | re-signed state tree broadcast (nSequence decremented — the odometer) |

A subtlety worth stating: **re-signing settles nothing on-chain.** It produces a new *agreed off-chain state* (the updated balances) and shortens the invalidation timelock; the funds stay pooled in the one shared UTXO. Settlement happens only at a **close** — cooperative (one distribution TX) or unilateral (broadcast the tree). This exhibit force-closes right after the advance purely to make the new state *visible* on-chain; in normal operation that broadcast never happens.

## Exhibit 11 — Distribution at expiry (the offline-forever safety net)

If a factory reaches its shared CLTV **without** rotating or cooperatively closing — the clients are gone and no one drove a coordinated exit — the LSP broadcasts a **pre-signed, multi-party co-signed, client-favored distribution transaction** that spends the funding root and pays every client their balance directly on-chain. It needs no live cooperation at expiry: every party co-signed it at factory creation, so *anyone* can broadcast it once the timelock matures. Here a minimized factory (N=2, arity-2) reached its CLTV at block 312659 and the LSP auto-broadcast the distribution, which confirmed at 312660:

| height | txid | what it is |
|---|---|---|
| 312660 | [`9f3e0829…`](https://mempool.space/signet/tx/9f3e082943b4133261525d6e98137317535365c8f49f0535c4ae059ac9050997) | co-signed distribution TX at CLTV expiry (nLockTime 312659, 167 vB, 3 outputs — one per participant) |

An honest note, because it is exactly the kind of thing this exhibition exists to catch: producing this exhibit **surfaced and fixed a real bug**. The single-process `--test-distrib` path had been *rebuilding* the distribution TX with placeholder demo keys, which cannot spend a strong-key funding output — it was rejected on-chain with `Invalid Schnorr signature`. The fix routes the exhibit through the **actual** transaction the creation ceremony co-signs (`dist_signed_tx`), which is what a real deployment broadcasts. So this exhibit both demonstrates the mechanism and validates the production signing path end-to-end.

## Exhibit 12 — JIT channels (just-in-time inbound liquidity)

A client that needs inbound liquidity it doesn't yet have can be handed a **just-in-time channel**: on demand, the LSP funds a fresh 2-of-2 (LSP + client) channel from its own on-chain wallet, waits for confirmations, and the channel opens — no factory rebuild required. Here the ceremony was driven deterministically (`--test-jit`) and opened a real 50,000-sat channel on signet:

| height | txid | what it is |
|---|---|---|
| 312657 | [`6d580835…`](https://mempool.space/signet/tx/6d580835f2913e68924c943c73771893b8dc49e1844e3157663f7d87ce6f1988) | JIT channel funding (2-of-2 LSP+client, 50k sats, channel id 0x8000) |

The channel opened, the lifecycle test passed, and it then cooperatively closed cleanly. This is the first JIT channel exercised on **real signet** — earlier attempts kept *cooperatively closing the factory instead*, because a dying factory whose clients are cooperating correctly prefers rotation / coop-close over spinning up new JIT liquidity. `--test-jit` forces the JIT path so the mechanism can be shown on-chain.

## The full lifecycle: laddering and its liveness cost

Stitching the exhibits into a factory's whole life: **create** (Exhibit 6) → **use** (real payments, Exhibit 6) → **checkpoint/advance** (Exhibit 10) → **rotate to a new epoch** (Exhibit 5) or **cooperatively retire** (Exhibit 8, 8/8) → or, if cooperation fails, **exit unilaterally** (Exhibits 1–3) or fall back to **distribution at expiry** (Exhibit 11).

One honest limit surfaced here: driving a *single continuous factory* through **multiple** rotations back-to-back needs every client online and cooperating at **each** epoch boundary. That worked at one boundary (8/8, `c116878`), but a multi-epoch standalone run stalled when clients didn't all cooperate at a turnover — the same N-of-N liveness dependency as the 127-client close below. The rotation *mechanism* is proven; sustaining it across many epochs is an operational cost, not a protocol guarantee.

---

## Honest findings

The exhibition is deliberately not airbrushed. Three things are worth stating plainly, because they are real properties of the system, not blemishes to hide:

- **A cooperative close at N=127 is a liveness bet.** The 24-hour soak lost roughly a quarter of its client daemons to ordinary attrition (running 127 daemons on one modest host is demanding). A cooperative close is N-of-N — it needs *every* participant — so it correctly could not complete and **fell back to force-close**. This is the designed behavior, and a useful data point: very large factories pay a real liveness cost, which is exactly why the timeout-tree fallback exists. (The funds were then recovered via the 128-key aggregate spend in Exhibit 7.)
- **Distribution-at-expiry is a fallback, not the default.** When clients cooperate, a dying factory **rotates or cooperatively closes** (Exhibits 5 and 8) — the better outcome. A pre-signed distribution that fires purely on expiry is the safety net for when rotation *cannot* happen (clients gone) — now demonstrated on-chain in Exhibit 11 — so with cooperative clients the LSP correctly prefers rotation.
- **Fees and timing.** Signet was congested during parts of this run, so low-fee transactions confirmed slowly. For the *cooperative* paths shown here this is harmless — their timing is relative, and a late confirmation simply shifts the schedule. Fee-adequacy only becomes security-critical on the **adversarial** recourse paths (a penalty or poison that must confirm before a timelock matures), which is treated separately in the [Security Model](#deep-dives/security-model) and network-economics work.

## Provenance and recovery

All runs used strong, per-run keys (never publicly-derivable weak keys), so every output is recoverable by its operator and none is left sweepable by outsiders. After the exhibition, the bridge channel was cooperatively closed and every factory-funding-root residual was swept back to a single wallet — the same MuSig reconstruction used for Exhibit 7's close doubles as the recovery path.
