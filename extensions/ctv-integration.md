# CTV Integration (OP_CHECKTEMPLATEVERIFY)

BIP-119 introduces `OP_CHECKTEMPLATEVERIFY` (CTV) — an opcode that constrains an output to only be spent by a transaction matching a pre-committed hash. For SuperScalar, CTV's primary benefit is **eliminating multi-round signing from tree interior nodes**, making factory open faster and simpler.

---

## The Problem CTV Solves

Building a SuperScalar factory today requires N-of-N MuSig2 signatures on every node in the tree: kickoff, state nodes at each layer, and leaf state nodes. For a factory with depth 3 and branching factor 4, that's 21 internal nodes plus the leaf channels — all requiring coordinated signing before the funding transaction is broadcast.

CTV allows the funding transaction output to commit (via a hash) to the exact structure of the child tree. Interior nodes no longer need signatures — they are enforced by the hash commitment itself.

---

## How CTV Changes Factory Open

**Today:**
```
1. Build entire tree structure
2. Sign every interior node (N-of-N MuSig2, multiple rounds)
3. Sign leaf channels (N-of-N MuSig2)
4. Broadcast funding tx
```

**With CTV:**
```
1. Hash the entire tree structure → CTV commitment
2. Embed CTV commitment in funding tx output script
3. Sign leaf channels only (N-of-N MuSig2)
4. Broadcast funding tx — interior nodes are now trustlessly enforced by the hash
```

Interior node outputs use a script like:
```
OP_CHECKTEMPLATEVERIFY
```
...where the output commits to the hash of the exact child transaction. No signatures. No signing rounds for tree structure. Only the leaf-level payment channels still require N-of-N coordination.

---

## What CTV Does Not Change

CTV constrains the tree *structure* — it does not help with state updates. Channel state updates within a leaf still require N-of-N signatures from the two parties. Factory-level state updates (the DW invalidation mechanism) still require N-of-N from all factory participants, because those update the active channel balances.

CTV also does not enable cooperative refresh — that requires APO. CTV-committed trees are structurally fixed; you can use DW invalidation within the committed structure, but you cannot rotate to a new tree without posting an on-chain transaction.

| Component | Today | With CTV |
|---|---|---|
| Interior node signing | N-of-N MuSig2 required | Eliminated (hash-enforced) |
| Leaf channel signing | N-of-N MuSig2 required | Unchanged |
| State update signing | N-of-N MuSig2 required | Unchanged |
| Factory rotation | On-chain tx required | Unchanged |
| Unilateral exit | Unchanged | Unchanged |

---

## CTV + APO Together

The two upgrades are complementary and additive:

- **CTV** reduces signing complexity at factory open — fewer rounds, faster onboarding
- **APO** enables cooperative refresh — zero on-chain footprint for factory rotation

Combined, a SuperScalar factory would only require on-chain transactions when clients actually enter or exit. Interior signing is eliminated (CTV), and rotation is handled off-chain (APO). This is the long-run optimum for a channel factory.

---

## Tradeoff: Structural Flexibility

CTV commits to a specific tree structure at factory open. If the tree structure needs to change before the factory expires — say, to add or remove a client mid-cycle — a new on-chain funding transaction is required, or the change must be deferred to the next rotation.

This is acceptable in practice: SuperScalar's rotation lifecycle already handles client entry/exit at rotation boundaries. CTV makes the in-rotation period cheaper without constraining the rotation model itself.

---

## Status

CTV is specified in [BIP-119](https://github.com/bitcoin/bips/blob/master/bip-0119.mediawiki) and requires a soft fork. It is not yet activated on mainnet. The SuperScalar codebase constructs tree nodes in `factory.c` (`build_subtree`) and tapscripts in `tapscript.c`. Adding CTV support would modify tapscript output construction for interior nodes; leaf and signing logic is unaffected.
