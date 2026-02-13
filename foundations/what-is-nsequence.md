# What Is nSequence? (Relative Timelocks)

> **Summary**: A field in every Bitcoin transaction input that can enforce a **relative timelock** — "this transaction cannot confirm until X blocks after its parent confirms." This is the mechanism that makes Decker-Wattenhofer invalidation work.

## How nSequence Works (BIP-68)

Every Bitcoin transaction input has a 32-bit `nSequence` field. When certain bits are set, it enforces a **relative timelock**:

```
BIP-68 nSequence encoding:
[31]    = disable flag (if set, BIP-68 relative timelock is not enforced)
[30:23] = reserved (must be zero for BIP-68 enforcement)
[22]    = type flag (0 = blocks, 1 = 512-second intervals)
[15:0]  = value (number of blocks or number of 512-second intervals)
```

The relative timelock encoded in `nSequence` is enforced at the consensus level (BIP-68). Scripts can additionally require a minimum relative timelock using `OP_CHECKSEQUENCEVERIFY` (BIP-112/CSV), which verifies that the spending transaction's `nSequence` is at least a specified value.

```mermaid
graph LR
    P["Parent TX<br/>confirms in block 100"] -->|"nSequence = 144 blocks"| C["Child TX<br/>can't confirm until block 244"]
```

**Example**: If a parent transaction confirms at block 100 and the child has `nSequence = 144`, the child cannot be included in any block before 244.

## Application in Decker-Wattenhofer

In [[decker-wattenhofer-invalidation|Decker-Wattenhofer]], each state update gets a **lower** nSequence than the previous one:

```mermaid
graph TD
    F["Funding TX<br/>(on-chain)"] --> S0["State 0<br/>nSequence = 432 blocks<br/>(oldest)"]
    F --> S1["State 1<br/>nSequence = 288 blocks"]
    F --> S2["State 2<br/>nSequence = 144 blocks"]
    F --> S3["State 3<br/>nSequence = 0 blocks<br/>(newest — wins race)"]

    style S0 fill:#ff6b6b,color:#fff
    style S3 fill:#51cf66,color:#fff
```

All these state transactions spend the **same output** (only one can confirm). Since State 3 has `nSequence = 0`, it is eligible for inclusion in the next block. State 0 must wait 432 blocks. Even if a cheater broadcasts State 0 first, State 3 becomes eligible sooner.

## Trade-off: Finite States

Each step costs you some delay. With a step size of 144 blocks:

| States Available | Starting Delay | Step Size |
|-----------------|---------------|-----------|
| 4 states | 432 blocks (~3 days) | 144 blocks |
| 8 states | 1008 blocks (~7 days) | 144 blocks |
| 16 states | 2160 blocks (~15 days) | 144 blocks |

More states = longer initial delay = longer worst-case force-close time.

This is why SuperScalar uses the [[the-odometer-counter|odometer counter]] — by stacking multiple layers, you get exponentially more states without linearly increasing the delay.

## nSequence = 0 vs nSequence Disabled

These two values have different semantics:

| Value | Meaning |
|-------|---------|
| `nSequence = 0` | Timelock is **enabled** but set to zero blocks — confirms immediately |
| `nSequence = 0xFFFFFFFF` | Timelock is **disabled** — the field is ignored entirely |

In the SuperScalar [[factory-tree-topology|factory tree]]:
- **State nodes** use decreasing nSequence values (the DW mechanism)
- **Kickoff nodes** use `nSequence = 0xFFFFFFFF` (disabled) — they confirm immediately and aren't part of the time-delay race

## Related Concepts

- [[decker-wattenhofer-invalidation]] — The full state machine that uses nSequence
- [[the-odometer-counter]] — How multiple layers multiply state capacity
- [[kickoff-vs-state-nodes]] — Why some nodes use nSequence and others don't
- [[what-is-a-payment-channel]] — The broader context of off-chain state
