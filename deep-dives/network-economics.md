# Network Economics

> **Summary**: Concrete cost and capital model for a deployed SuperScalar network. One on-chain UTXO shared by N clients delivers dramatically lower per-user on-chain cost than individual Lightning channels while preserving full non-custodial security.

## The Unit of Account: The Factory

A SuperScalar factory is the fundamental unit of deployed capital. It holds N clients (typically 8–64), all sharing one on-chain UTXO. The LSP's economics are driven by three factors:

1. **On-chain costs** — factory funding and rotation transactions
2. **Capital cost** — liquidity locked in the factory over its lifetime
3. **Revenue** — fees charged to clients for channel access and liquidity

---

## On-Chain Cost Per User

### Factory Funding Transaction

A factory funding transaction is a standard P2TR output, indistinguishable on-chain from a single-signature Taproot spend.

| Component | vbytes |
|---|---|
| Transaction overhead | 10 |
| Input (P2TR keypath spend) | 58 |
| Factory output (P2TR) | 43 |
| Change output (P2TR) | 43 |
| **Total** | **≈154 vbytes** |

With N clients sharing this transaction, the per-user amortized opening cost is:

| Factory size | Per-user cost (vbytes) | vs. standard LN channel open |
|---|---|---|
| 8 clients | 19 vbytes | 8× cheaper |
| 16 clients | 10 vbytes | 16× cheaper |
| 32 clients | 5 vbytes | 32× cheaper |
| 64 clients | 2.4 vbytes | 64× cheaper |

A standard Lightning channel open is ≈154 vbytes per user. SuperScalar's shared UTXO delivers **8–64× on-chain efficiency** at factory open.

### Rotation Cost (Laddering)

With [[laddering]], a 30-day factory requires one new funding transaction per rotation. At 10 sat/vbyte:

| | |
|---|---|
| Funding tx cost | ≈1,540 sat |
| Per user, 32-client factory | ≈48 sat/month |
| Per user, per year | ≈576 sat |

At ≈$85,000/BTC, 576 sat ≈ **$0.49/year** in on-chain costs per user. A standard Lightning channel open + close is ≈308 vbytes total — at 10 sat/vb, 3,080 sat (≈$2.62) per channel lifetime with no shared benefit and no path to further reduction.

---

## Force-Close Cost

Worst-case unilateral exit publishes the path from the factory root to the affected client's leaf. For a binary tree with 8 clients (depth 3):

| Transaction | vbytes |
|---|---|
| Kickoff root | 111 |
| State root | 154 |
| Kickoff subtree | 111 |
| State subtree | 154 |
| Kickoff leaf | 111 |
| State leaf | 197 |
| Channel commitment | 167 |
| **Total path** | **≈1,005 vbytes** |

Only clients in the affected subtree are impacted — not the entire factory. In a 32-client factory with binary tree depth 5, a force-close by one client affects at most 3 others sharing that leaf subtree.

For comparison, a standard Lightning force-close is ≈300–600 vbytes. A SuperScalar force-close costs roughly 3× more on-chain — the price of sharing a UTXO across multiple participants — and it is a rare event. The cooperative path adds no on-chain cost beyond the rotation transaction.

---

## Capital Deployment

An LSP with 30 laddered factories (one expiring per day) deploys capital as follows:

| Parameter | Value |
|---|---|
| Clients per factory | 32 |
| Average client balance | 100,000 sat |
| LSP liquidity per factory | ≈640,000 sat (≈20%) |
| Total per factory | ≈3,840,000 sat |
| Factories in rotation | 30 |
| **Total LSP capital** | **≈115,200,000 sat (≈1.15 BTC)** |
| **Clients served** | **960** |
| **On-chain footprint** | **1 tx/day** |

960 active Lightning clients, one on-chain transaction per day — the same footprint as a single standard Lightning channel open.

---

## Revenue Model

The LSP charges clients a recurring fee covering:

```
Monthly fee = amortized funding tx cost
            + LSP liquidity opportunity cost
            + watchtower / infrastructure cost
            + margin
```

Because the factory rotation schedule is regular and predictable (one transaction per ladder rung per day), the LSP can negotiate feerate futures with mining pools to stabilize the on-chain cost component — enabling a fixed monthly fee regardless of mempool conditions.

---

## Covenant Upgrade Path

If APO (BIP-118) activates, the DW state limit is removed — factories support unlimited state updates per rotation cycle instead of the current interior-layer state cap (16 epochs with the default 2 DW layers, up to 64 with deeper interiors; PS leaf advances consume no epoch). Laddering rotation transactions remain, but the protocol sustains higher-frequency liquidity purchases without consuming state budget. Per-user rotation cost is unchanged; the gain is headroom, not fewer on-chain transactions.

If CTV (BIP-119) activates, factory construction no longer requires all clients online simultaneously. LSPs can pre-build factories during off-peak hours and clients confirm participation asynchronously, removing the coordination deadline from the rotation lifecycle.

Neither upgrade is required. SuperScalar deploys and operates on Bitcoin today.

---

## Related Concepts

- [[laddering]] — The rotation model that produces predictable daily on-chain cost
- [[client-migration]] — How clients move between factories without force-closing
- [[force-close]] — The unilateral exit path and its on-chain cost
- [[apo-integration|APO Integration]] — How covenant upgrades affect the cost model
- [[soft-fork-landscape]] — Full soft fork landscape and probability estimates
