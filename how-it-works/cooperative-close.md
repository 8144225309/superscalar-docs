# Cooperative Close

> **TLDR**: When a factory's lifetime ends and all clients cooperate, everyone signs a single transaction that distributes funds cleanly. No tree transactions need to be published. This is the ideal outcome — cheap, fast, and private.

## The Happy Path

If everything goes right — all clients come online during the [[laddering|dying period]] and cooperate — the entire factory can be closed with a **single on-chain transaction**:

```mermaid
graph LR
    F["Funding UTXO<br/>(1.0 BTC)"] -->|"One cooperative tx<br/>(key-path spend)"| O1["Alice: 0.15 BTC"]
    F --> O2["Bob: 0.12 BTC"]
    F --> O3["Carol: 0.08 BTC"]
    F --> O4["Dave: 0.05 BTC"]
    F --> O5["LSP: 0.58 BTC"]
    F --> O6["New Factory<br/>Funding UTXO"]
```

Because the funding UTXO is a [[what-is-taproot|Taproot]] output with an N-of-N [[what-is-musig2|MuSig2]] key path, a cooperative close looks like a **normal single-signature Bitcoin transaction** on-chain. Nobody can tell a factory was involved.

## Why This Is Optimal

| Metric | Cooperative Close | [[force-close|Force Close]] |
|--------|------------------|------------|
| On-chain transactions | **1** | O(log N) tree txs + channel closes |
| Total fees paid | Minimal (one tx) | Substantial (many txs) |
| Time to completion | 1 block | Days (DW delays + to_self_delay) |
| Privacy | Perfect (looks like normal tx) | Leaks tree structure |
| LSP capital recovery | Immediate | Delayed by timelocks |

## How It Works

### During the Dying Period

1. Factory enters its 3-day dying period
2. LSP sends push notifications to all clients
3. Clients come online one by one

### When All Clients Are Online

1. **LSP proposes** final balances based on current channel states
2. All clients **verify** their balances are correct
3. Everyone participates in a **MuSig2 signing ceremony** for the close transaction
4. The close transaction is **broadcast** — spends the funding UTXO via key path
5. Clients receive their funds (either on-chain or in a new factory)

### Combining Close + New Factory

In the ideal [[laddering]] flow, the cooperative close of the old factory and the funding of the new factory happen in the same transaction:

```
Close + Fund TX:
  Input:  Old factory funding UTXO (key-path spend)
  Output 1: New factory funding UTXO
  Output 2: On-chain payouts for departing clients
  Output 3: Change back to LSP
```

This is why laddering can achieve ~1 on-chain transaction per day.

## What If Not Everyone Cooperates?

If one or more clients don't come online during the dying period:

```mermaid
flowchart TD
    D["Dying period starts"]
    D --> C{"All clients<br/>online?"}
    C -->|"Yes"| CO["Cooperative close ✅<br/>1 transaction"]
    C -->|"Some missing"| P["Partial cooperative close<br/>+ force-close for absent clients"]
    C -->|"Nobody online"| FC["Full force close ⚠️<br/>Publish entire tree"]
```

**Partial cooperation**: The LSP and online clients can cooperatively handle their portions, while absent clients' subtrees are force-closed. The tree structure means absent clients only affect their own branch.

## The Endogenous Fee Recovery

During factory construction, small fees were embedded in each tree transaction (endogenous fees). On cooperative close:

> *"Tree node fees are recovered if the LSP reaps the UTXO without publishing the entire tree."* — ZmnSCPxj

Since the tree is never published, those fees never get paid to miners. The LSP recovers them — they were essentially a deposit against the possibility of force-close.

## Related Concepts

- [[force-close]] — What happens when cooperation fails
- [[laddering]] — The lifecycle that leads to cooperative close
- [[client-migration]] — How clients move to new factories
- [[building-a-factory]] — The ceremony that created the factory
- [[what-is-musig2]] — The signing protocol for the close transaction
