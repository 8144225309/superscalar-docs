# Shachain Revocation

> **Summary**: When the factory state updates, the LSP reveals a secret for the old state. If the LSP later tries to broadcast that old state, clients can use the secret to claim the LSP's funds as penalty. This makes cheating economically irrational.

## The Problem

In the [[factory-tree-topology|factory tree]], the LSP has **liquidity stock** — funds it owns that it uses to sell inbound liquidity to clients. When the factory state advances (via the [[the-odometer-counter|odometer]]), the liquidity stock amounts change. What stops the LSP from broadcasting an old state where it had MORE liquidity stock?

[[decker-wattenhofer-invalidation|Decker-Wattenhofer invalidation]] handles this for the tree structure (newer states confirm first), but the LSP might still try to broadcast an old state just before its nSequence catches up. We need an additional punishment layer.

## The Solution: Secret-Based Punishment

Each LSP liquidity stock output has a hidden spending condition:

```mermaid
graph TD
    LS["LSP Liquidity Stock Output"]
    LS --> N["Normal Path<br/>LSP's key<br/>(honest spend)"]
    LS --> P["Punishment Path<br/>Shachain secret + any key<br/>(burns funds to fees)"]

    style N fill:#51cf66,color:#fff
    style P fill:#ff6b6b,color:#fff
```

The script on the liquidity stock looks like:

```
OP_IF
    <shachain_secret_hash> OP_EQUALVERIFY <anyone_key> OP_CHECKSIG
OP_ELSE
    <LSP_key> OP_CHECKSIG
OP_ENDIF
```

### How the punishment works:

1. Factory is at **epoch 5**. The LSP shares the shachain secret for **epoch 4** with the co-signing clients.
2. If the LSP broadcasts the epoch 4 state, clients know the secret for epoch 4's liquidity stock.
3. Clients create a **burn transaction** that spends the liquidity stock using the secret path and sends **the entire amount as fees to miners**.
4. The LSP's funds are destroyed. Cheating is economically irrational.

```mermaid
sequenceDiagram
    participant LSP
    participant Clients
    participant Chain as Blockchain

    Note over LSP,Clients: State advances from epoch 4 to epoch 5
    LSP->>Clients: Here's the shachain secret for epoch 4

    Note over LSP: LSP tries to cheat...
    LSP->>Chain: Broadcasts epoch 4 state tx

    Clients->>Chain: Burn tx: spends L-stock with secret,<br/>entire value goes to miners as fees
    Note over Chain: LSP's liquidity stock destroyed 🔥
```

## What Is a Shachain?

A shachain is a **compact secret derivation tree** from the Lightning Network spec (BOLT #3). It lets you derive 2^48 unique secrets from a single 32-byte seed, with these properties:

- **Forward secrecy**: Revealing secret N doesn't reveal secret N+1
- **Compact storage**: The receiver only needs to store O(log N) values to reconstruct any previously-revealed secret
- **Deterministic**: Given the seed and an index, anyone can compute the exact secret

```mermaid
graph TD
    S["Seed (32 bytes)"] --> S0["Secret 0"]
    S --> S1["Secret 1"]
    S --> S2["Secret 2"]
    S --> S3["Secret 3"]
    S --> SN["Secret N..."]

    style S fill:#4c6ef5,color:#fff
```

```
shachain_from_seed(seed, 0) → secret_0
shachain_from_seed(seed, 1) → secret_1
shachain_from_seed(seed, 2) → secret_2
...
```

Each factory epoch uses the corresponding shachain index. When advancing from epoch 2 to epoch 3, the LSP reveals `secret_2`. Now clients can punish any attempt to use epoch 2's liquidity stock outputs.

## Why Burn to Fees Instead of Giving to Clients?

You might wonder: why not give the stolen funds to the clients instead of miners?

The answer is **incentive alignment**. If clients received the LSP's funds when catching a cheat, there would be a perverse incentive for clients to **provoke** the LSP into appearing to cheat, or for clients to grief the LSP. By burning the funds to miner fees:

- The LSP loses money (punishment works)
- Clients gain nothing from provoking cheating
- Miners get a windfall (neutral third party)
- The threat alone is sufficient deterrent — it never actually needs to happen

## Compact Storage with Shachain Receiver

When the LSP shares old secrets with clients, clients don't need to store every single secret. The shachain receiver algorithm (from BOLT #3) stores at most **O(log N)** elements and can derive any previous secret from them:

```
Epoch 0: Store secret_0                    (1 element stored)
Epoch 1: Store secret_1, derive secret_0   (2 elements stored)
Epoch 2: Store secret_2, derive 0,1        (2 elements stored)
Epoch 3: Store secret_3                    (3 elements stored)
...
Epoch 63: Still only ~6 elements stored!
```

This is the same algorithm Lightning uses for revoking old commitment transactions, adapted here for factory state revocation.

## When Is Shachain Used vs DW?

Both are invalidation mechanisms, but they protect different things:

| Mechanism | Protects | Against |
|-----------|----------|---------|
| **Decker-Wattenhofer** | Tree structure (which state tx confirms) | Anyone broadcasting old state |
| **Shachain revocation** | LSP liquidity stock amounts | LSP specifically trying to reclaim sold liquidity |

DW is **automatic** (new states win the time race). Shachain is **economic** (cheating costs more than it gains). Together, they make the factory secure.

## Related Concepts

- [[decker-wattenhofer-invalidation]] — The time-delay mechanism that shachain complements
- [[the-odometer-counter]] — Each odometer epoch corresponds to a shachain index
- [[factory-tree-topology]] — Where liquidity stock outputs live in the tree
- [[what-is-an-lsp]] — Why the LSP has liquidity stock in the first place
- [[security-model]] — Full analysis of the combined security properties
