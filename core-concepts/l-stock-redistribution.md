# L-stock SPK + Redistribution TX

> The canonical security mechanism for factory liquidity stock, replacing the older OP_RETURN burn from [t/1143](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories/1143).
> Design: ZmnSCPxj, [Delving Bitcoin t/1242](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories-with-pseudo-spilman-leaves/1242) (November 2024).

## What the L-stock is

Each leaf in the factory tree holds an output called the **LSP liquidity stock** ("L-stock") — funds the LSP has set aside to sell inbound liquidity to clients in that leaf. Without protection, this output is a target: an LSP could publish a stale leaf state where it had more L-stock than the current state, effectively clawing back liquidity it already sold.

## The canonical SPK construction

The L-stock output is a Taproot output with two spend paths:

```
internal key  = MuSig(LSP, client_1, ..., client_K)         "A & B & L"
script-leaf   = <csv_blocks> OP_CSV OP_DROP <LSP_xonly> OP_CHECKSIG
```

- **Key-path (N-of-N MuSig)** — used by:
  - The legitimate cooperative-close path (everyone signs)
  - The pre-signed **redistribution transaction** that activates if the LSP publishes an old (revoked) leaf state
- **Script-path (`L & CSV`)** — the LSP's unilateral fallback, gated by a relative-locktime delay (a small number of blocks, on the order of a day)

The CSV gate gives clients and watchtowers time to broadcast the matching pre-signed redistribution TX before the LSP can unilaterally drain L-stock.

## The redistribution TX

When the LSP publishes a stale leaf state, anyone (any client or the watchtower) can broadcast the matching **pre-signed redistribution transaction** to redirect L-stock value to clients.

```
Input:    L-stock UTXO from the stale leaf state
Outputs:  1 per non-LSP signer
            each = (L-stock amount − fee) / n_clients
            paid to P2TR(client_xonly) — key-path only, client controls
Witness:  64-byte Schnorr signature from the N-of-N MuSig key-path,
          pre-signed at leaf-state-advance time
```

The LSP receives nothing. Each client controls their own output unilaterally.

### Worked example (from t/1242)

Initial state: L-stock = 20 units, channels A=10, B=10.

If LSP publishes the stale leaf state:
- Channel with A: 10 units → entirely to A (via standard Poon-Dryja revocation on the inner channel)
- Channel with B: 10 units → entirely to B
- L-stock: 20 → equal-split → 10 to A, 10 to B (via the redistribution TX)

ZmnSCPxj's framing:

> *"In total, `A` and `B` each get 20 units of protection."*

## Why this replaced OP_RETURN burn

The earlier t/1143 design destroyed L-stock value via OP_RETURN. The current canonical design **redistributes** L-stock to clients instead. This:

- Preserves total value (no burning)
- Gives clients direct economic incentive to CPFP the redistribution TX (they own the outputs unilaterally)
- Strengthens deterrence (LSP loses, clients gain)

ZmnSCPxj's explanation:

> *"all the funds into `A` or `B` unilaterally. But because the LSP does not own any money in the outputs of those transactions, it does not want the 'poison' transaction published."*

## Co-signed at every state advance

The redistribution TX has to be co-signed **at every state advance**. The reason is straightforward: the redistribution TX spends the L-stock UTXO of a specific leaf state, and that UTXO is fresh for every state. So when a leaf advances from state N to state N+1, the participants must produce a redistribution TX for state N+1's L-stock UTXO — otherwise the new state has no matching cheating-recovery TX.

The co-signing is bundled into the same signing ceremony as the state advance itself, not run as a separate ceremony.

## Security argument

Cheating = LSP publishes a STALE (already-revoked) leaf state, hoping to roll back to a state where it had more capital in L-stock or its own channel side.

**What happens if the LSP publishes a stale state:**

1. The stale leaf state TX's L-stock UTXO appears on chain
2. The matching pre-signed redistribution TX (already in clients' and watchtower's hands from when that state was advanced past) becomes valid
3. Anyone broadcasts the redistribution TX. Per t/1242: *"any client can trivially CPFP the 'poisoning' transaction"* — clients have unilateral control of their share, so they have direct economic incentive to CPFP if needed
4. L-stock value is redirected to clients (equal split). LSP gets **nothing** from L-stock
5. The leaf's channel outputs (A&L, B&L) are independently recoverable via standard Poon-Dryja revocation
6. Net: cheating LSP loses (a) all L-stock + (b) all channel capital that was its share at the time of the stale state

The stale state by definition had **less favorable** balance for the LSP than the new state (otherwise why advance?), and the redistribution TX strips the entire L-stock. The LSP is strictly worse off publishing stale state.

## Sockpuppet limitation (acknowledged)

ZmnSCPxj's t/1242 acknowledges this honestly:

> *"the LSP cannot really present any proof that `A` is indeed a genuine client that is not a sockpuppet the LSP actually controls, so for maximum security for `B`, it should assume that `A` is a sockpuppet of the LSP `L`."*

If client B's balance exceeds `(L-stock / n_real_clients)`, a hostile LSP could sybil with fake clients to dilute B's per-client redistribution share. Mitigation: voluntary external UTXO reserve ("deposit insurance") for clients with substantial holdings — they fund their own exogenous fee payment for unilateral close.

## References

- ZmnSCPxj, [SuperScalar with Pseudo-Spilman Leaves (Delving t/1242)](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories-with-pseudo-spilman-leaves/1242)
- ZmnSCPxj, [SuperScalar (Delving t/1143)](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories/1143) — original design with OP_RETURN burn (now obsolete for L-stock)
