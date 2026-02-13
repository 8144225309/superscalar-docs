# Factory Tree Topology

> **Summary**: The factory is a tree of pre-signed transactions rooted in a single shared UTXO. Internal nodes split participants into smaller groups. Leaf state nodes produce standard Lightning channel outputs. The tree alternates between kickoff nodes (circuit breakers) and state nodes (Decker-Wattenhofer state machines).

## Why a Tree?

The fundamental tension in SuperScalar is:

- **N-of-N is secure** — nobody can steal
- **N-of-N is fragile** — everyone must cooperate to update state

If you have 8 clients and the LSP (9 signers), getting everyone online simultaneously is hard — especially for mobile wallet users. A tree solves this by creating **subtrees** where only the local participants need to cooperate:

```mermaid
graph TD
    R["Root: 9-of-9<br/>All 8 clients + LSP"]
    R --> L["Left: 5-of-5<br/>Clients A,B,C,D + LSP"]
    R --> Ri["Right: 5-of-5<br/>Clients E,F,G,H + LSP"]
    L --> LL["Left-Left: 3-of-3<br/>Clients A,B + LSP"]
    L --> LR["Left-Right: 3-of-3<br/>Clients C,D + LSP"]
    Ri --> RL["Right-Left: 3-of-3<br/>Clients E,F + LSP"]
    Ri --> RR["Right-Right: 3-of-3<br/>Clients G,H + LSP"]
```

Leaf updates (the most common case) only need 3 signers — 2 clients + the LSP — rather than coordinating all 9.

## The Full Tree (8 Clients)

The complete factory tree for an LSP with 8 clients (A through H):

```
                                                          nSequence
                                                          +---+---+
                                                          |   |A&L| LN channel
                                                          |   +---+
                                                      +-->|432|B&L| LN channel
                                                      |   |   +---+
                                                      |   |   | L | Liquidity stock
                                                      |   +---+---+
                                                      |    state_left_left
                                                      |
                                                      |   +---+---+
                                                      |   |   |C&L| LN channel
                         nSequence             +------+   |   +---+
                         +---+----------+  +-->| A&B&L|-->|432|D&L| LN channel
                         |   |(A..D&L)  |  |   | kickoff  |   +---+
         +--+---------+  |   |or(L&CLTV)|--+   +------+   |   | L | Liquidity stock
funding->|  |A..H & L |->|432+----------+   |              +---+---+
         |  | kickoff  |  |   |(E..H&L)  |  |              state_left_right
         +--+---------+  |   |or(L&CLTV)|--+
           kickoff_root  +---+----------+   |   +------+   +---+---+
                          state_root    +-->| E&F&L|   |   |E&L| LN channel
                                            | kickoff  |   |   +---+
                                            +------+-->|432|F&L| LN channel
                                                   |   |   +---+
                                                   |   |   | L | Liquidity stock
                                                   |   +---+---+
                                                   |    state_right_left
                                                   |
                                                   |   +---+---+
                                                   |   |   |G&L| LN channel
                                                   |   |   +---+
                                                   +-->|432|H&L| LN channel
                                                       |   +---+
                                                       |   | L | Liquidity stock
                                                       +---+---+
                                                        state_right_right
```

## Layer by Layer

### Layer 0: Kickoff Root
- **Spends**: The shared funding UTXO
- **Signers**: All 8 clients + LSP (9-of-9)
- **nSequence**: Disabled (no delay)
- **Purpose**: Initiates the unilateral exit process

### Layer 1: State Root
- **Spends**: Kickoff root output
- **Signers**: All 8 clients + LSP (9-of-9)
- **nSequence**: [[decker-wattenhofer-invalidation|DW Layer 0]] (decrements each epoch)
- **Outputs**: Two outputs, each for a subtree of 4 clients + LSP
- **Timeout**: Each output has [[timeout-sig-trees|CLTV timeout]] script path for LSP recovery

### Layer 2: Kickoff Nodes (Left & Right)
- **Spends**: One output from the state root
- **Signers**: 4 clients + LSP (5-of-5) per side
- **nSequence**: Disabled (no delay)
- **Purpose**: Circuit breakers — see [[kickoff-vs-state-nodes]]

### Layer 3: State Nodes (Leaves)
- **Spends**: One output from their kickoff node
- **Signers**: 2 clients + LSP (3-of-3) per leaf
- **nSequence**: [[decker-wattenhofer-invalidation|DW Layer 1]] (decrements independently)
- **Outputs**: Individual Lightning channels + LSP liquidity stock

## Leaf Outputs: What Lives at the Bottom

Each leaf state node has 3 outputs:

```mermaid
graph TD
    S["State Node (Leaf)<br/>Signed by: Alice, Bob, LSP"]
    S --> CH_A["Alice & LSP Channel<br/>2-of-2 MuSig2<br/>Standard Poon-Dryja LN channel"]
    S --> CH_B["Bob & LSP Channel<br/>2-of-2 MuSig2<br/>Standard Poon-Dryja LN channel"]
    S --> LS["LSP Liquidity Stock<br/>LSP-only funds<br/>Used to sell inbound liquidity"]
```

### Client Channels (A&L, B&L)
Standard Lightning channels. Once the factory tree is set up, these work exactly like normal Lightning — Alice can send and receive payments through the LSP without touching the factory at all.

### LSP Liquidity Stock (L)
Funds the LSP has set aside to sell inbound liquidity to clients. Protected by [[shachain-revocation|shachain secrets]] so the LSP can't cheat by broadcasting an old state where it had more liquidity stock.

## Why the LSP Is in Every Subtree

The LSP participates in every node of the tree:

- It is one party in every leaf channel
- It coordinates signing rounds for state updates
- It provides liquidity at every level

The N-of-N multisig means the LSP has no unilateral spending power — it cannot move funds without every other participant signing.

## Arity: How Many Branches Per Node?

The **arity** (branching factor) of the tree is a tunable parameter:

| Arity at Leaves | Clients Per Leaf | Signers Needed for Leaf Update |
|----------------|-----------------|-------------------------------|
| 2 | 2 clients | 3 (2 clients + LSP) |
| 3 | 3 clients | 4 (3 clients + LSP) |
| 4 | 4 clients | 5 (4 clients + LSP) |

**Recommended: Arity 2 at leaves** — only 3 signers needed for the most common updates. Higher arity means more coordination difficulty.

For higher-level nodes (where the groups are already large), higher arity is acceptable since the marginal coordination cost of adding one more signer to an already-large group is small.

## Collateral Damage on Force-Close

When one client force-closes, **sibling subtrees are affected but the other half of the tree is not**:

```mermaid
graph TD
    R["Root"] --> L["Left Half"]
    R --> Ri["Right Half<br/>(unaffected)"]
    L --> LL["Alice & Bob<br/>(channels published on-chain)"]
    L --> LR["Carol & Dave<br/>(channels published on-chain)"]

    style Ri fill:#51cf66,color:#fff
    style LL fill:#ff922b,color:#fff
    style LR fill:#ff922b,color:#fff
```

If Alice force-closes:
- **Alice**: Fully exits to on-chain
- **Bob** (same leaf): Channel goes on-chain, still works, but loses cheap off-chain liquidity management
- **Carol, Dave** (sibling leaf, same half): Their subtree must also resolve on-chain because the shared kickoff node was published
- **Eve, Frank, Grace, Heidi** (other half): **Zero impact** — their subtree was never published

## Related Concepts

- [[kickoff-vs-state-nodes]] — Why the alternation between node types is mandatory
- [[the-odometer-counter]] — How DW layers in the tree map to the odometer
- [[decker-wattenhofer-invalidation]] — The state machine at each state node
- [[timeout-sig-trees]] — The timeout scripts on internal outputs
- [[building-a-factory]] — How this tree is actually constructed
- [[force-close]] — Detailed walkthrough of unilateral exit
