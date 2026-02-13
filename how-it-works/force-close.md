# Force Close (Unilateral Exit)

> **Summary**: If the LSP misbehaves or a client cannot cooperate, any participant can publish pre-signed tree transactions on-chain. The Decker-Wattenhofer mechanism ensures the newest state wins. The process is expensive and slow, but funds are recoverable (subject to dust economics — very small balances may cost more in fees than they are worth).

## When Does Force-Close Happen?

| Scenario | Who Initiates |
|----------|--------------|
| LSP goes offline permanently | Client |
| LSP refuses to cooperate | Client |
| Client misses dying period and never returns | LSP (via CLTV timeout path) |
| Suspected cheating | Either party |
| LSP shut down by authorities | All clients |

Force-close is the **last resort**. Multiple tree transactions must be published on-chain, and Decker-Wattenhofer delays accumulate at each state layer.

## The Process (8-Client Factory, Arity 2)

Alice wants to exit unilaterally from a factory with 8 clients:

```mermaid
sequenceDiagram
    participant A as Alice
    participant Chain as Blockchain

    A->>Chain: 1. Publish kickoff_root (confirms next block)
    Note over Chain: No relative timelock (kickoff nSequence = 0xFFFFFFFF)

    A->>Chain: 2. Publish state_root (latest version)
    Note over Chain: DW Layer 0 delay: up to 432 blocks

    Note over Chain: If cheater published old state_root,<br/>Alice's newer version wins the race

    A->>Chain: 3. After state_root confirms:<br/>Publish kickoff_left (confirms next block)
    Note over Chain: No relative timelock

    A->>Chain: 4. Publish state_left (latest version)
    Note over Chain: DW Layer 1 delay: up to 432 blocks

    A->>Chain: 5. Publish state_left_sibling (must also resolve)
    Note over Chain: DW Layer 1 delay

    Note over Chain: Alice's channel is now on-chain

    A->>Chain: 6. Standard Poon-Dryja close of A&L channel
```

### Transaction Count

```
1 kickoff_root + 1 state_root + 1 kickoff_left + 2 state_leaves + 1 channel close
= 6 transactions total
```

In general: **O(log N) tree transactions + 1 channel close**.

## The DW Race

At each state node level, a race happens:

```mermaid
graph TD
    subgraph "The Race at State Root Level"
        SR_OLD["Old state_root (epoch 0)<br/>nSeq = 432<br/>Must wait 432 blocks"]
        SR_NEW["New state_root (epoch 2)<br/>nSeq = 144<br/>Waits 144 blocks"]
    end

    SR_NEW -->|"Confirms first"| CONFIRM["Spends the UTXO"]
    SR_OLD -->|"Delay not yet elapsed"| INVALID["Becomes invalid<br/>(UTXO already spent)"]

    style SR_NEW fill:#51cf66,color:#fff
    style SR_OLD fill:#ff6b6b,color:#fff
```

This is the [[decker-wattenhofer-invalidation|Decker-Wattenhofer mechanism]]: a shorter nSequence always wins the race for the same UTXO.

## The [[kickoff-vs-state-nodes|Kickoff Circuit Breaker]]

Notice the alternation: kickoff → state → kickoff → state. The kickoff nodes **isolate** the DW races at each level. Without them, replacing a state at one level would invalidate all the pre-signed transactions below it.

## Collateral Damage

Not everyone is equally affected:

```mermaid
graph TD
    R["Root"] --> L["Left Half"]
    R --> Ri["Right Half<br/>(unaffected)<br/>Subtree stays off-chain"]

    L --> LL["Alice & Bob<br/>(affected)<br/>Channels go on-chain"]
    L --> LR["Carol & Dave<br/>(affected)<br/>Channels go on-chain"]

    style Ri fill:#51cf66,color:#fff
    style LL fill:#ff922b,color:#fff
    style LR fill:#ff922b,color:#fff
```

| Party | Impact |
|-------|--------|
| **Alice** (exiting) | Fully exits — gets her funds on-chain |
| **Bob** (same leaf as Alice) | Channel goes on-chain; still functional but loses factory benefits |
| **Carol, Dave** (same half of tree) | Same as Bob — their kickoff must also be resolved |
| **Eve, Frank, Grace, Heidi** (other half) | **Completely unaffected** — their subtree was never published |

The tree structure **contains the blast radius**. Only Alice's half of the tree is affected.

## Fee Bumping with P2A

Every tree transaction includes a **P2A (Pay-to-Anchor)** output — a special output that anyone can spend to attach a CPFP (Child-Pays-for-Parent) fee bump:

```
Tree TX outputs:
  Output 0: Taproot (normal tree output)
  Output 1: P2A (anyone can spend → attach fee-bump child tx)
```

This solves the fee estimation problem: tree transactions are pre-signed with low endogenous fees. If the mempool is congested at force-close time, any participant can bump the fee by spending the P2A output.

### Shachain Protection for P2A

What prevents a griefing attack where someone fee-bumps an OLD state transaction? The [[shachain-revocation|shachain mechanism]]:

- Old state transactions have liquidity stock outputs locked to revealed shachain secrets
- If an old state confirms, clients can burn the LSP's liquidity stock to miner fees
- This makes it economically irrational for the LSP to broadcast old states

## Timing: How Long Does It Take?

Worst-case timing for a 2-layer DW factory:

| Step | Duration |
|------|----------|
| Kickoff root confirms | 1 block (~10 min) |
| State root DW delay | Up to 432 blocks (~3 days) |
| Kickoff left confirms | 1 block (~10 min) |
| State left DW delay | Up to 432 blocks (~3 days) |
| Channel-level to_self_delay (Poon-Dryja) | ~144 blocks (~1 day) |
| **Total worst case** | **~7 days** |

This is significantly worse than a regular Lightning force-close (~1 day). The longer delay is the cost of sharing a UTXO among multiple participants.

## The Inverted Timelock Safety Net

With the [[timeout-sig-trees|inverted timelock]] design, even if a client cannot publish the tree (e.g., they lost the pre-signed transactions), a pre-signed `nLockTime` transaction exists that distributes funds to clients once the factory's CLTV timeout height is reached:

> Any party holding a copy of the pre-signed timeout transaction can broadcast it after the CLTV height. The LSP must act before the timeout or lose its capital locked in the factory.

## Related Concepts

- [[decker-wattenhofer-invalidation]] — The race mechanism at each state level
- [[kickoff-vs-state-nodes]] — Why the alternation prevents cascade failures
- [[shachain-revocation]] — Punishment for broadcasting old states
- [[cooperative-close]] — The much better alternative
- [[security-model]] — Threat analysis and trust assumptions, including force-close guarantees
