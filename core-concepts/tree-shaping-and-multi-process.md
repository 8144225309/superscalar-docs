# Mixed-Arity Trees, Sub-Factories, and Multi-Process Operation

> Three closely-related design features that together let a single factory hold many clients (verified to 128) with worst-path exit time inside BOLT's 2016-block CLTV ceiling, while letting each participant run in their own process — typically on their own machine.

## Why mixed arity

Every Decker-Wattenhofer state layer contributes `step_blocks × (states_per_layer − 1)` blocks of BIP-68 CSV delay to the worst-case unilateral-exit path. A binary tree of depth `d` stacks this delay linearly in tree depth. Combined with the BOLT 2016-block `final_cltv_expiry` ceiling, this caps the factory size — a uniformly-binary tree at N=128 has worst-path delay 3456 blocks, which exceeds the ceiling.

ZmnSCPxj's recommendation in [t/1242](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories-with-pseudo-spilman-leaves/1242):

> *"The best arity for leaf nodes is 2 … The tree can have low arity near the leaves, then increase the arity when building nodes a few levels away from the leaves. Beyond a few layers away from the leaves, we could entirely remove state transactions (i.e. those with decrementing nSequences) … a root timeout-sig-tree that backs multiple timeout-tree-structured Decker-Wattenhofer mechanisms."*

> *"Kickoff nodes may also have an arity of 1 … this reduces the number of affected clients if one client wants to unilaterally exit."*

Three handles for tree shape:

1. **Low-arity leaves** — pseudo-Spilman leaves carry one client per leaf (see [[pseudo-spilman-leaves]]).
2. **Wider arity mid-tree** — interior layers can fan out at independently-configurable arities (for example `2,4,8`), collapsing depth so the DW delays don't stack as far.
3. **Static near-root** — the top few depths near the root can be made kickoff-only (no paired state node, no DW counter), removing their contribution to the worst-path delay budget entirely.

The canonical production shape combines all three.

## A worked production shape

```
Funding UTXO
  │
  Kickoff Root          (depth 0, static-only — no DW counter)
    │
    Kickoff Mid Layer 1 (depth 1, static-only)
      │  ┐
      │  │ (arity 2 → 4 → 8 expansion)
      │  ┘
      Kickoff Mid Layer 2 (depth 2, paired with state)
        State Mid Layer 2 (depth 2 — the only DW layer in this shape)
          │
          PS Leaf Chains (one client + LSP per leaf, 2-of-2 MuSig)
```

For comparison:

| Shape | N | Worst-path delay | BOLT 2016 status |
|-------|---|------------------|------------------|
| Uniformly binary | 128 | 3456 blocks | rejected (exceeds ceiling) |
| Mixed-arity 2,4,8 | 64 | ≤ 2016 blocks | valid |
| Mixed-arity 2,4,8 with static-near-root 2 | 128 | 864 blocks | canonical |

The 864-block worst-path delay at N=128 leaves ample slack inside the BOLT 2016-block ceiling for routing CLTV delta on the HTLCs carried by the inner channels.

## Sub-factories: k² PS chain extension

A pseudo-Spilman leaf is a chain; each state advance appends one TX. Eventually a leaf's channel may want to extend further than the original construction provides for. When that happens, the chain can be extended by inserting a new k² sub-factory layer — a small additional tree segment that the existing leaf chain spends into.

Like the other state-advance ceremonies, sub-factory extension co-signs the matching [redistribution TX](l-stock-redistribution.md) at the same time, so any L-stock UTXO in the extended chain has a pre-signed cheating-recovery TX from the moment it exists.

## Multi-process operation

In production, the LSP and each client typically run as separate OS processes — usually on different machines. The MuSig2 ceremonies coordinate partial signatures across all those processes over the wire (see the [[blip-56-integration|BLIP-56 wire integration]] for the underlying message-carrier).

The multi-process path is BIP-327-equivalent to the single-process path — partial sigs travel over a wire, but the cryptographic protocol and security properties are identical. The honest-case path produces fully signed transactions including the bundled redistribution TX for every state-bearing node.

## References

- ZmnSCPxj, [SuperScalar with Pseudo-Spilman Leaves (Delving t/1242)](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories-with-pseudo-spilman-leaves/1242) — arity recommendation
- BIP-68 (relative timelocks via nSequence)
- BOLT 2 `final_cltv_expiry` — the 2016-block ceiling driving the shape constraint

## Related

- [[pseudo-spilman-leaves]] — the canonical leaf mechanism

- [[l-stock-redistribution]] — the cheating-recovery mechanism co-signed at every state advance
- [[factory-tree-topology]] — how the tree is laid out
