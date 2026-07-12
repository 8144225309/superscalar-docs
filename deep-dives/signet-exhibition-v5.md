# SuperScalar on Signet: A Live Exhibition

> **Summary**: SuperScalar's mechanisms aren't only described in these docs — they've been **run end-to-end on real signet**, and every step left an on-chain transaction you can inspect for yourself. This page follows the **life of a pseudo-Spilman channel factory** — created, funded, used with real Lightning payments, checkpointed, laddered to fresh epochs, and cooperatively retired — and then the exception paths: what happens when a party won't cooperate, and what happens when one cheats. Every step has a real transaction ID. It also records, honestly, the things that did *not* go to plan, because those are findings too.

All transactions below are on **signet**, built by SuperScalar **v0.2.0**. **Every txid links to the live transaction on [mempool.space](https://mempool.space/signet)** — click any of them to inspect the real on-chain data.

The keystone result: a **127-client factory funded, paid through with real Lightning HTLCs, and cooperatively closed** — settled by a single on-chain transaction, **one input to 128 outputs**, confirmed on signet and conserving to the satoshi. (What the chain proves directly, versus what the software attests about that transaction, is spelled out precisely in Exhibit 6 — this page is careful about the difference.)

## The exhibits at a glance

The exhibits are ordered by a factory's life: first the **normal (happy) path**, then the **fallbacks** for when cooperation fails, then the **adversarial** case.

**Part I — A normal factory's life**

| # | stage | on-chain proof | block(s) |
|---|---|---|---|
| 1 | Create, fund & **use** (99 real Lightning payments, 24 h) | [`143471b5…`](https://mempool.space/signet/tx/143471b5d1ddc0eee3ea54d74ed17081f24d48f429bb826723c8b0897e55c0e6) | 312349 |
| 2 | Provision inbound liquidity — **JIT channel** | [`6d580835…`](https://mempool.space/signet/tx/6d580835f2913e68924c943c73771893b8dc49e1844e3157663f7d87ce6f1988) | 312657 |
| 3 | **Checkpoint** state — Decker–Wattenhofer odometer | [`6e3264f7…`](https://mempool.space/signet/tx/6e3264f7c2c8676e8eec757296e2463568655419a76f1a26b095abbf55bf5e08) | 312619 |
| 4 | **Refresh** — ladder to a new epoch | [`d766282…`](https://mempool.space/signet/tx/d766282072e58b4ed4775cde9f71d97bea32dab1f8f5f95be931ffdb7ce382d5) → [`09762ddd…`](https://mempool.space/signet/tx/09762dddc6f977de0a94bc9d0f1ab670a419c6482a3b493b77c365f3e47cb980) | 312379–385 |
| 5 | **Retire** cooperatively (N=8, rotation → close) | [`c116878…`](https://mempool.space/signet/tx/c116878091ce0f5d5aa1b812edd119fd1408b9308579eda3ea2836ca687f3af7) | 312543 |
| **6** | **Live 127-party cooperative close** — real payments, then one signature | [`d1468287…`](https://mempool.space/signet/tx/d1468287a30839962ca849d9b88f3f6442e9d6a357141180a401ce1b4d0dd727) | **312777** |

**Part II — When cooperation fails (fallbacks & safety nets)**

| # | stage | on-chain proof | block(s) |
|---|---|---|---|
| 7 | Unilateral exit — force-close + keyless P2A anchors + CPFP | [`4648fc2e…`](https://mempool.space/signet/tx/4648fc2e7c122f227109eac285d804fa6d374832a7fabfb6e20359a7ae12d700) | 312264–267 |
| 8 | Unilateral exit — the legible cascade (N=8, five P2A nodes) | [`2d054df3…`](https://mempool.space/signet/tx/2d054df38cecbec834c5c1ac3640faa7f981f86bf75700262c0717c0724b1839) | 312339–346 |
| 9 | Unilateral exit — a single client (@ 1 sat/vB) | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) | 312366–369 |
| 10 | Timelock enforcement — 144-block CSV, proven by heights | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) | 312369 → 312510 |
| 11 | Distribution at expiry — the offline-forever safety net | [`9f3e0829…`](https://mempool.space/signet/tx/9f3e082943b4133261525d6e98137317535365c8f49f0535c4ae059ac9050997) | 312660 |

**Part III — Adversarial: punishing a cheat** (the headline security property)

| # | stage | on-chain proof | block(s) |
|---|---|---|---|
| 12 | Revealed-secret poison → redistribution | [`e82035f2…`](https://mempool.space/signet/tx/e82035f2b724c0c16225fada682af20684a91bc04aa62f59718a1a2e3c4a53a2) cheat → [`d2ae19cf…`](https://mempool.space/signet/tx/d2ae19cf39547b7eb69930ef8ad92e3d7f51e683b02cd8643a74d45640d4a4f0) poison | 312269–272 |

The story it tells top-to-bottom: a factory is **created and used** → clients get **JIT inbound** → balances **checkpoint** → it **ladders** to fresh epochs → it **retires cooperatively at the design maximum**. Only then: *what if someone won't cooperate* (unilateral exit, timelocks, expiry distribution), and finally *what if someone cheats* (the poison).

## How SuperScalar uses the chain

SuperScalar is a **channel factory**: a single on-chain UTXO — one P2TR output owned by an N-of-N MuSig2 aggregate of the LSP and up to 127 clients — backs many Lightning channels at once. The whole point is to keep Bitcoin's base layer *out* of the common path. Onboarding a client, routing a payment, and moving balances all happen **off-chain**, as transactions the participants re-sign among themselves but never broadcast. The chain is touched only at a handful of well-defined moments — and every exhibit below is one of them:

- **Create** — one funding transaction pays sats into the shared N-of-N output. From then on, every client's balance lives *inside that one UTXO*.
- **Operate (off-chain)** — payments and balance updates leave **no** on-chain trace. A newer state supersedes an older one, enforced by a shortening relative-timelock (the "odometer"); balances only *become* on-chain sats at a close. → *[what this factory actually carried off-chain, and the scale economy](#deep-dives/offchain-and-scale)*
- **Add inbound on demand (JIT)** — when a client needs liquidity it doesn't have, the LSP funds a fresh 2-of-2 channel for it — a small, targeted on-chain open, not a factory rebuild.
- **Retire cooperatively** — when everyone agrees, the entire factory settles in **one transaction with a single aggregated Schnorr signature**, no matter how many clients it held. This is the efficient, expected ending (Exhibit 6).
- **Exit unilaterally** — a client who can't get cooperation broadcasts the pre-signed timeout-tree transactions, producing a cascade from the factory root down to its own channel — each hop fee-bumpable through a keyless anchor, and gated by a 144-block CSV so a newer state always beats a stale one.
- **Punish a cheat** — if a party broadcasts a superseded state to steal, recourse redistributes the cheater's own stake to the victims (revealed-secret poison), and a secret-less watchtower confirms the justice transaction on-chain.
- **Fail safe** — if the factory simply reaches its deadline with everyone gone, a distribution transaction — co-signed in advance by all parties — pays each client their balance with no further cooperation needed.

So the on-chain footprint is deliberately small and specific: a birth, a death, and a fixed menu of recourse paths for when cooperation breaks down. Everything below is one of those moments, captured as a real transaction on **real signet**, produced by the v0.2.0 software — not a mock or a unit test, but the code driving a live Bitcoin network. The traffic was real where it counted, too: balances came from actual Lightning payments — in the flagship, routed in from an **unmodified, non-bLIP-56 CLN node** through the bridge — rather than from synthetic numbers.

---

# Part I — A normal factory's life

## 1. Create, fund, and use — the 127-client factory with real payments

The flagship, and the natural start of the story. One LSP plus **127 clients** — the design maximum (128 signers, tree depth 7) — behind a single P2TR UTXO, with **no free sats**: clients start empty and earn balance from real inbound Lightning payments routed through the bridge from a vanilla CLN node.

| height | txid | what it is |
|---|---|---|
| 312349 | [`143471b5…`](https://mempool.space/signet/tx/143471b5d1ddc0eee3ea54d74ed17081f24d48f429bb826723c8b0897e55c0e6) | **127-client factory funding**, then **99 real routed payments** over a ~24 h soak |

The payments settle off-chain as Lightning HTLCs, so the factory's on-chain footprint is the funding plus its eventual close — but the traffic in between was real. This one UTXO is the shared home for all 127 clients' balances. (What became of *this* factory's cooperative close — and what the 24-hour soak taught us about sustaining 127 daemons — is discussed honestly under *What N=127 demonstrated*, near the end of this page.)

## 2. Just-in-time inbound liquidity (JIT channels)

A client that needs inbound liquidity it doesn't yet have can be handed a **just-in-time channel**: on demand, the LSP funds a fresh 2-of-2 (LSP + client) channel from its own on-chain wallet, waits for confirmations, and the channel opens — no factory rebuild required. Here the ceremony was driven deterministically (`--test-jit`) and opened a real 50,000-sat channel on signet:

| height | txid | what it is |
|---|---|---|
| 312657 | [`6d580835…`](https://mempool.space/signet/tx/6d580835f2913e68924c943c73771893b8dc49e1844e3157663f7d87ce6f1988) | JIT channel funding (2-of-2 LSP+client, 50k sats, channel id 0x8000) |

The channel opened, the lifecycle test passed, and it then cooperatively closed cleanly. This is the first JIT channel exercised on **real signet** — earlier attempts kept *cooperatively closing the factory instead*, because a dying factory whose clients are cooperating correctly prefers rotation / coop-close over spinning up new JIT liquidity. `--test-jit` forces the JIT path so the mechanism can be shown on-chain.

## 3. Checkpointing state — the Decker-Wattenhofer odometer

Inside a factory, balances are updated **off-chain** by re-signing the state tree. Each update **decrements the state's relative-timelock (nSequence)** — the "odometer" — so a newer state can always be published ahead of a stale one, which is how old states are invalidated. Here a factory advanced its DW counter and the state nodes' nSequence stepped **down** on-chain:

```
Node 3: nSequence 0x32 (50) → 0x1E (30)
Node 5: nSequence 0x32 (50) → 0x1E (30)
```

| height | txid | what it is |
|---|---|---|
| 312619 | [`6e3264f7…`](https://mempool.space/signet/tx/6e3264f7c2c8676e8eec757296e2463568655419a76f1a26b095abbf55bf5e08) | re-signed state tree broadcast (nSequence decremented — the odometer) |

A subtlety worth stating: **re-signing settles nothing on-chain.** It produces a new *agreed off-chain state* (the updated balances) and shortens the invalidation timelock; the funds stay pooled in the one shared UTXO. Settlement happens only at a **close** — cooperative (one transaction, Exhibit 6) or unilateral (broadcast the tree). This exhibit force-closes right after the advance purely to make the new state *visible* on-chain; in normal operation that broadcast never happens. It is the single on-chain glimpse of an otherwise entirely off-chain process — see *[the off-chain layer](#deep-dives/offchain-and-scale)*.

## 4. Refreshing — laddering to a new epoch

A live factory doesn't have to force-close to be refreshed. When clients cooperate, the LSP **rotates** it: close the old epoch and fund a new one on-chain, extending the useful life without a mass exit.

| height | txid | what it is |
|---|---|---|
| 312374 | [`14900ae8…`](https://mempool.space/signet/tx/14900ae867a7f34f2d9390e74b2c0af801cb8467f16bf31cf2cf9eb5fb6b8dbf) | factory funding |
| 312379 | [`d766282…`](https://mempool.space/signet/tx/d766282072e58b4ed4775cde9f71d97bea32dab1f8f5f95be931ffdb7ce382d5) | old-epoch on-chain close (rotation step 1) |
| 312385 | [`09762ddd…`](https://mempool.space/signet/tx/09762dddc6f977de0a94bc9d0f1ab670a419c6482a3b493b77c365f3e47cb980) | new-epoch funding (rotation complete) |

## 5. Retiring cooperatively at legible N — rotation into a cooperative close

When a factory reaches the end of its schedule and its clients are online, the LSP's preferred path is not a force-close but a **cooperative** one: a key turnover followed by a clean close. Here an 8-client factory reaches its dying window and closes with **all 8 clients cooperating** — the same mechanism as Exhibit 6, at a size small enough to read every output.

| height | txid | what it is |
|---|---|---|
| 312532 | [`6aa35632…`](https://mempool.space/signet/tx/6aa35632cbeedeb5a92c22d30de962f8ad4cdcb8c8c335f693790766cab6203c) | factory funding (N=8) |
| 312543 | [`c116878…`](https://mempool.space/signet/tx/c116878091ce0f5d5aa1b812edd119fd1408b9308579eda3ea2836ca687f3af7) | **clean cooperative close via rotation — 8/8 clients cooperated** |

## 6. The live 127-party cooperative close — real payments, then one signature

The keystone. A fresh factory at the **design maximum** — one LSP + **127 clients** — funded, **used with real Lightning payments**, and then **cooperatively closed by all 127 clients signing live**. This is the genuine ceremony: not an operator reconstructing keys after the fact, but 127 independent client daemons plus the LSP, each contributing its own partial signature, aggregated into one Schnorr signature that spends the shared UTXO.

| height | txid | what it is |
|---|---|---|
| — | [`72c0790e…`](https://mempool.space/signet/tx/72c0790e2e58a9970fe8f8d4ded10800fb55f1bc04cdd93f22267e58f401f25b) | 127-client factory funding |
| (off-chain) | — | **8 real HTLC payments** settled end-to-end through the channels, plus demo payments |
| **312777** | [`d1468287…`](https://mempool.space/signet/tx/d1468287a30839962ca849d9b88f3f6442e9d6a357141180a401ce1b4d0dd727) | **live 127-party cooperative close** — **1 input** (the shared factory UTXO) → **128 outputs** (LSP + 127 clients), one aggregated 128-key Schnorr signature |

**What the chain proves, and what we attest — kept separate on purpose.** On mempool.space, anyone can verify *directly*: **one input** (the shared factory UTXO) → **128 outputs**, spent by a single **key-path** Schnorr signature, with **12,094,231 sats** out against a **5,732-sat fee** — exact conservation, nothing created or destroyed. Two things a taproot **key-path** spend deliberately *cannot* reveal — it is byte-for-byte indistinguishable whether one key signed or a hundred did — we **attest** from the software and its logs, we do not claim the chain shows them:

- that lone signature is the **MuSig2 aggregate of all 128 participant keys** — each client daemon contributed its partial signature in the live ceremony (a real cooperative close, not one party signing for all);
- each of the 128 outputs equals that participant's balance **to the satoshi** — senders down by exactly what they sent, receivers up by exactly what they received, idle clients untouched — independently reconciled off-chain as *on-chain output == the LSP's ledger == expected*.

The full per-client arithmetic, legible at a smaller N where every line can be checked by eye, is in the *[Security Model](#deep-dives/security-model)*.

This is the cooperative close as it actually runs: many signers, real traffic first, one on-chain transaction to settle it all. (One honest caveat for completeness: these 127 clients were 127 independent daemons driven by one test operator on one host — separate keys, DBs, and processes, each signing on its own — not 127 unrelated people; the *protocol* treats them as independent signers, which is what the aggregate close exercises.)

> An earlier artifact, [`0ca6b929`](https://mempool.space/signet/tx/0ca6b929e2d7a52633b33d3a0a36f531d6230f49ffccbac7486977d745aa1056) (block 312535), is the same *shape* — a design-max key-path spend of a 128-signer factory root — but it was assembled at **teardown by the operator** (who held every seed) to recover the flagship of Exhibit 1, **not** produced by a live 127-daemon ceremony. It stands only as the recovery artifact; **Exhibit 6 above is the live cooperative close**, which is the claim that matters.

---

# Part II — When cooperation fails (fallbacks & safety nets)

Everything above assumed cooperating parties. The protocol's real value is that it stays safe when they don't — a client can always leave, and funds are never trapped.

## 7. Unilateral exit — force-close + keyless anchors + CPFP

A client can always leave without the LSP's cooperation by broadcasting the pre-signed timeout-tree transactions. Each carries a **keyless P2A (pay-to-anchor) output** (`51024e73`) so that *anyone* can fee-bump a stuck exit with a child transaction (CPFP) — important when many parties may be racing the same block space.

| height | txid | what it is |
|---|---|---|
| 312264 | [`c7ad28fa…`](https://mempool.space/signet/tx/c7ad28faecc4a754eb5e9f2bffd2430129d69b9c200c41a654ea56ebb1b09fac) | factory funding (250k sat) |
| 312265 | [`bee9cbf5…`](https://mempool.space/signet/tx/bee9cbf5c44ef951b521832a703c1ed34432878d080e0848534130b7aa9fa84a) | anchored force-close |
| 312266 | [`ecac2791…`](https://mempool.space/signet/tx/ecac2791a686e821c5ecb60560cbe8c62ebaca4bb99174c9f9caebcc7d3a6ab7) | anchored force-close (second state) |
| 312267 | [`4648fc2e…`](https://mempool.space/signet/tx/4648fc2e7c122f227109eac285d804fa6d374832a7fabfb6e20359a7ae12d700) | **CPFP child spending a P2A anchor** — the fee-bump, on-chain |

## 8. Unilateral exit — the legible cascade (N=8)

The same exit, shaped to be readable: an 8-client, arity-2 factory force-closes mid-schedule, producing the full cascade (kickoff → state → leaf → close). **Every node carries its own P2A anchor.**

| height | txid | what it is |
|---|---|---|
| 312339 | [`2d054df3…`](https://mempool.space/signet/tx/2d054df38cecbec834c5c1ac3640faa7f981f86bf75700262c0717c0724b1839) | factory funding |
| 312340 | [`2b10e8d1…`](https://mempool.space/signet/tx/2b10e8d168c1f5af7963284116f832a2526f8b8415a9d4ca83a671ee9ff49961) | force-close cascade node (P2A) |
| 312342 | [`1d96af3a…`](https://mempool.space/signet/tx/1d96af3add57e8507a92b56215eea004c29a4783545c40948fbaa92e1fcd77ed) | force-close cascade node (P2A) |
| 312343 | [`cba7274f…`](https://mempool.space/signet/tx/cba7274f26b6c88b08af84b9dfe71933da8e5d563404aa9520339e0992e68b05) | force-close cascade node (P2A) |
| 312345 | [`b2f95397…`](https://mempool.space/signet/tx/b2f953974b6f20438cd29e57d7f4da926f7ca3452034ad3e877afbd6d884dba7) | force-close cascade node (P2A) |
| 312346 | [`b2c97bbe…`](https://mempool.space/signet/tx/b2c97bbeb9f02bbecbed09c40ba6d4e65b8918b32e8d95baee3afb251ce342ed) | force-close cascade node (P2A) |

## 9. Unilateral exit — a single client forcing its way out

The minimal case: one client force-closing its own small factory at 1 sat/vB, which enables the commitment-level anchor. This confirms the anchors re-enable at ≥1 sat/vB with no extra flag.

| height | txid | what it is |
|---|---|---|
| 312366 | [`978f62f6…`](https://mempool.space/signet/tx/978f62f662eb1c8180f7c617b4e7ef6a1d30eaf8fb3fb281cc21550a03fdd053) | factory funding |
| 312367 | [`1fbc8f2f…`](https://mempool.space/signet/tx/1fbc8f2f7b1fcf470a239c6c8f0f88ef6ab5794c226eb554e17b67b023be1ee4) | force-close node (P2A @ 1 sat/vB) |
| 312369 | [`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223) | force-close / commitment node (P2A) |

## 10. The timelock, proven by block heights

The timeout-tree leaves are timelock-gated (144-block CSV). Rather than a separate transaction, the proof is the **confirmation-height delta**: an output created at height *H* cannot be spent until *H + 144*, and stays unspent through the whole window.

- Legible cascade (Exhibit 8): base **312339** → outputs unspendable until **312483**.
- Single-client commitment ([`a28bb6f7…`](https://mempool.space/signet/tx/a28bb6f7de7949fe0aaacdbc561f09970592e4b35c3585c4f41d0f7f3b56a223), Exhibit 9): base **312369**, its outputs CSV-locked and unspent through the window, spendable only at **312510**.

Anyone can verify this on-chain with no cooperation from us.

## 11. Distribution at expiry — the offline-forever safety net

If a factory reaches its shared CLTV **without** rotating or cooperatively closing — the clients are gone and no one drove a coordinated exit — the LSP broadcasts a **pre-signed, multi-party co-signed, client-favored distribution transaction** that spends the funding root and pays every client their balance directly on-chain. It needs no live cooperation at expiry: every party co-signed it at factory creation, so *anyone* can broadcast it once the timelock matures. Here a minimized factory (N=2, arity-2) reached its CLTV at block 312659 and the LSP auto-broadcast the distribution, which confirmed at 312660:

| height | txid | what it is |
|---|---|---|
| 312660 | [`9f3e0829…`](https://mempool.space/signet/tx/9f3e082943b4133261525d6e98137317535365c8f49f0535c4ae059ac9050997) | co-signed distribution TX at CLTV expiry (nLockTime 312659, 167 vB, 3 outputs — one per participant) |

An honest note, because it is exactly the kind of thing this exhibition exists to catch: producing this exhibit **surfaced and fixed a real bug**. The single-process `--test-distrib` path had been *rebuilding* the distribution TX with placeholder demo keys, which cannot spend a strong-key funding output — it was rejected on-chain with `Invalid Schnorr signature`. The fix routes the exhibit through the **actual** transaction the creation ceremony co-signs (`dist_signed_tx`), which is what a real deployment broadcasts. So this exhibit both demonstrates the mechanism and validates the production signing path end-to-end.

---

# Part III — Adversarial: punishing a cheat

The happy path keeps funds safe when parties cooperate; the fallbacks keep them safe when parties simply vanish. This last part is the one that keeps them safe when a party is actively **malicious** — the headline security property.

## 12. The revealed-secret poison

A party broadcasts a **stale, superseded sub-factory state** — an attempted theft. The victim's recourse assembles the revealed-secret **poison** transaction, which redistributes the cheater's sales-stock to the clients as punishment. See [Detecting LSP Misbehavior](#deep-dives/lsp-misbehavior) for the detection layer that triggers this.

| height | txid | what it is |
|---|---|---|
| 312266 | [`ae4e99a0…`](https://mempool.space/signet/tx/ae4e99a0601fd9db4fc26ee02ae928d1793ee770fbadd5741f5de25391705b4a) | sub-factory funding (200k) |
| 312267 | [`97ee1aa1…`](https://mempool.space/signet/tx/97ee1aa1e37f17dc3a315b63fab2aa78556d086cb0f624b0cfa6c932c8d09e49) | tree node 0 |
| 312268 | [`577d7e32…`](https://mempool.space/signet/tx/577d7e32da5a6b82c83ebbead50fbef0294a9d74154780203473b609ba53eaf0) | tree node 1 |
| 312269 | [`e82035f2…`](https://mempool.space/signet/tx/e82035f2b724c0c16225fada682af20684a91bc04aa62f59718a1a2e3c4a53a2) | **cheat** — broadcasts a stale/superseded sub-state |
| 312272 | [`d2ae19cf…`](https://mempool.space/signet/tx/d2ae19cf39547b7eb69930ef8ad92e3d7f51e683b02cd8643a74d45640d4a4f0) | **poison recourse** — 2-way redistribution, 21,085 sats to clients |

### And a secret-less watchtower behind it

The poison above is one arm of the recourse; the other is the **watchtower**, and it holds **no private keys** — only pre-signed penalty transactions in its `wt.db`. So even if the LSP vanishes, *anyone* can run a standalone watchtower that catches a revoked-state broadcast and confirms the penalty. We drive this end-to-end in the test suite — a revoked commitment is broadcast, and a secret-less watchtower (`wt.db` only, no keys) detects it and gets the pre-signed penalty confirmed, clawing the funds back so the cheater keeps nothing but the mining fee. The detection layer is described in [Detecting LSP Misbehavior](#deep-dives/lsp-misbehavior), and the full penalty matrix — factory, sub-factory, and channel-commitment — with its on-chain proofs is collected in the [Security Model](#deep-dives/security-model).

---

## The full lifecycle in one line

**create + use** (Exhibit 1) → **JIT inbound** (Exhibit 2) → **checkpoint** (Exhibit 3) → **ladder to a new epoch** (Exhibit 4) → **retire cooperatively** (Exhibits 5–6, the design-max live close). If cooperation fails: **exit unilaterally** (Exhibits 7–9), gated by **timelocks** (Exhibit 10), or fall back to **distribution at expiry** (Exhibit 11). If a party cheats: the **poison** and the **secret-less watchtower penalty** (Exhibit 12).

Rotation is proven at an epoch boundary — Exhibit 4, plus the 8/8 cooperative turnover in `c116878`. Like every cooperative step it is *optimistic*: each boundary needs the participants online, so chaining many epochs back-to-back is a matter of coordination, never of safety — if a turnover can't be assembled, every client simply keeps its unilateral exit (Exhibits 7–9).

---

## Cooperation is an optimization, not a requirement

The property to take from these exhibits: **no client depends on the LSP — or on the other clients — to recover its money.** Every level of the tree has a **unilateral exit** (Exhibits 7–9), gated by relative timelocks (Exhibit 10), and against a misbehaving party backed by revealed-secret recourse and a secret-less watchtower (Exhibit 12) and a pre-signed expiry distribution (Exhibit 11). None of those paths needs anyone else's permission.

The cooperative paths — rotation and cooperative close (Exhibits 4–6) — sit *on top of* that guarantee as an **optimization**: when everyone is online and agreeable, the whole factory settles in one small transaction instead of a force-close cascade. They need all participants online at once — a coordination property of the *efficient* path, not a safety one. If that coordination doesn't happen, nothing is at risk; each client simply takes its guaranteed unilateral exit.

### What N=127 demonstrated

127 clients is the *design maximum*. Two honest data points, not one:

- **The cooperative close works live at 127.** Exhibit 6 (`d1468287`) is the real ceremony: a 127-client factory funded, paid through with real HTLCs, and closed by **all 128 signers** in one on-chain transaction — 1 input → 128 outputs, confirmed on signet and conserving to the satoshi (the aggregate-signature and per-client-amount details are attested as noted in Exhibit 6). That is the claim that matters, and it is proven.
- **Sustaining 127 independent daemons for a full day is itself hard.** The flagship of Exhibit 1 ran all 127 client daemons on one modest host for a **~24-hour soak**. Over that window enough daemons drifted offline that a coordinated close of *that particular* factory couldn't be reassembled — so the system did exactly what it exists to do: **funds stayed fully retrievable**, and it settled on-chain via the 128-key aggregate spend (`0ca6b929`). Exercising the fallback is the trustless design working as intended.

The two together are the whole point: the protocol's cooperative path is proven at the design maximum, *and* its safety never rests on 128 parties staying continuously online — which is precisely why every client keeps a unilateral exit regardless.

Two scoping notes:

- **Distribution-at-expiry is the last-resort net, not the default.** With cooperating clients a dying factory rotates or cooperatively closes (Exhibits 4–6); the pre-signed distribution (Exhibit 11) exists for the case where no one is around to drive an exit at all.
- **Fee timing matters only on adversarial paths.** Signet was congested during parts of the run, so low-fee transactions confirmed slowly — harmless for cooperative paths (their timing is relative), and security-relevant only on a recourse race (a penalty or poison that must confirm before a timelock matures); see the [Security Model](#deep-dives/security-model).

## Provenance and recovery

All runs used strong, per-run keys (never publicly-derivable weak keys), so every output is recoverable by its operator and none is left sweepable by outsiders. After the exhibition, the bridge channel was cooperatively closed and every factory-funding-root residual was swept back to a single wallet — the same MuSig reconstruction used for the design-max aggregate spend doubles as the recovery path.
