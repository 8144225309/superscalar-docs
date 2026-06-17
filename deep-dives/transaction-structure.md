# Transaction Structure

> **Summary**: Every transaction in the SuperScalar factory tree is a standard Bitcoin transaction with specific version, nSequence, and witness fields that implement the DW mechanism, Taproot spending, and P2A fee-bumping.

## Transaction Types in the Factory

| Transaction | nVersion | nSequence | nLockTime | Witness |
|-------------|----------|-----------|-----------|---------|
| **Funding tx** | 2 | wallet default | 0 | LSP's regular spend |
| **Kickoff tx** | 2 | 0xFFFFFFFF (disabled) | 0 | MuSig2 key-path sig |
| **State tx** | 2 | BIP-68 relative delay | 0 | MuSig2 key-path sig |
| **Distribution tx** | 2 | 0xFFFFFFFE | nLockTime (inverted) | MuSig2 key-path sig |
| **Channel close** | 2 | varies (Poon-Dryja) | varies | Channel-specific |
| **Fee-bump child** | 2 | any | 0 | Spends P2A output |

### P2A Anchors and Fee-Bumping

P2A anchors appear on the **distribution transaction** and **channel commitment/penalty transactions** — not on tree node transactions (kickoff, state, leaf state). Tree transactions use endogenous fees baked in at signing time. The distribution tx's P2A anchor allows fee-bumping the final payout during force-close.

> **Upgrade path**: Migrating to `nVersion=3` (v3/TRUC policy, available since Bitcoin Core 28) allows P2A anchors to carry 0 sats via the ephemeral dust exemption introduced in Bitcoin Core 29.

## Funding Transaction

```
┌─────────────────────────────────────────────┐
│ Funding TX                                  │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ Input:  LSP's UTXO(s)                       │
│ Output 0: P2TR                              │
│   amount: total factory capacity            │
│   scriptPubKey: OP_1 <output_key>           │
│     internal_key = MuSig2(all clients, LSP) │
│     script tree = none (key-path only)      │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

The funding output is key-path only — no script tree. CLTV timeout scripts appear on subtree outputs deeper in the tree (state nodes and child kickoff nodes), not on the funding output itself. This ensures the LSP cannot unilaterally claim the entire factory balance at timeout; recovery is granular per-subtree.

On-chain, this output is indistinguishable from any other P2TR output. A cooperative key-path spend is indistinguishable from a single-signer Taproot spend.

## Kickoff Transaction

```
┌─────────────────────────────────────────────┐
│ Kickoff TX (e.g., kickoff_root)             │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ Input 0:                                    │
│   prev_txid: funding tx                     │
│   prev_vout: 0                              │
│   nSequence: 0xFFFFFFFF (disabled)          │
│   witness: <64-byte MuSig2 signature>       │
│                                             │
│ Output 0: P2TR (for state tx)               │
│   scriptPubKey: OP_1 <tweaked_key>          │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

Key properties:
- `nSequence = 0xFFFFFFFF`: Relative timelock **disabled** — no delay after parent confirms
- Single MuSig2 signature in witness (key-path spend)
- Exactly 1 output (the state node's P2TR address)
- Root kickoff has no script tree; non-root kickoff nodes include a CLTV timeout script-path leaf for [[timeout-sig-trees|LSP timeout recovery]]

## State Transaction

```
┌─────────────────────────────────────────────┐
│ State TX (e.g., state_root, epoch 2)        │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ Input 0:                                    │
│   prev_txid: kickoff_root                   │
│   prev_vout: 0                              │
│   nSequence: 144 (BIP-68 relative blocks)   │
│   witness: <64-byte MuSig2 signature>       │
│                                             │
│ Output 0: P2TR (left subtree)               │
│   amount: left subtree total                │
│   scriptPubKey: OP_1 <left_tweaked_key>     │
│     script tree: CLTV timeout               │
│                                             │
│ Output 1: P2TR (right subtree)              │
│   amount: right subtree total               │
│   scriptPubKey: OP_1 <right_tweaked_key>    │
│     script tree: CLTV timeout               │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

Key properties:
- `nSequence = 144`: BIP-68 relative timelock requiring 144 blocks after the parent confirms. This delay decreases with each epoch per the [[decker-wattenhofer-invalidation|DW mechanism]].
- Each P2TR output includes a CLTV script-path leaf for [[timeout-sig-trees|LSP timeout recovery]].
- Exactly 2 outputs for internal state nodes (left and right child subtrees).

## Leaf State Transaction

```
┌─────────────────────────────────────────────┐
│ Leaf State TX (canonical pseudo-Spilman)    │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ Input 0:                                    │
│   prev_txid: previous PS chain TX           │
│             (or parent kickoff for state 0) │
│   prev_vout: 0                              │
│   nSequence: 0xFFFFFFFE (BIP-68 disabled —  │
│              chain ordering is structural)  │
│   witness: <64-byte MuSig2 signature>       │
│             (2-of-2: client + LSP)          │
│                                             │
│ Output 0: P2TR (Client & LSP channel)       │
│   amount: channel capacity                  │
│   scriptPubKey: OP_1 <MuSig2(client, L)>   │
│                                             │
│ Output 1: P2TR (LSP liquidity stock)        │
│   amount: remaining liquidity               │
│   scriptPubKey: OP_1 <output_key>           │
│     internal: MuSig2(client, L)             │
│     script-leaf: <csv> CSV DROP <L> CHECKSIG│
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

The leaf carries one bidirectional BOLT-2 Lightning channel (Output 0) plus the LSP's liquidity stock (Output 1). State advances append a new TX to the chain rather than replacing the previous state via decrementing nSequence; see [[pseudo-spilman-leaves]] for the chain ordering semantics. The L-stock script-path is a relative-timelock-gated unilateral drain for the LSP (default ~144 blocks); the cooperative key-path is what every legitimate spend uses, and is also what the pre-signed [[l-stock-redistribution|redistribution TX]] uses if the LSP publishes a stale leaf state.

### L-stock script-path

```
<csv_blocks> OP_CHECKSEQUENCEVERIFY OP_DROP <LSP_xonly> OP_CHECKSIG
```

A relative-timelock gate on LSP unilateral drain of the L-stock. The CSV delay gives clients and the watchtower time to broadcast the matching pre-signed redistribution TX if the LSP is publishing a stale state.

## Distribution Transaction

The distribution transaction is a pre-signed `nLockTime`d transaction that distributes factory funds directly to clients if the LSP disappears before the CLTV timeout. It includes a **P2A anchor** for CPFP fee-bumping at broadcast time.

```
┌─────────────────────────────────────────────┐
│ Distribution TX                             │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ nLockTime: <block height>                   │
│                                             │
│ Output 0: Client A's funds                  │
│ Output 1: Client B's funds                  │
│ ...                                         │
│ Output N: P2A (fee-bump anchor)             │
│   amount: 240 sats                          │
│   scriptPubKey: OP_1 <0x4e73>               │
└─────────────────────────────────────────────┘
```

The 240-sat anchor cost is deducted from the LSP's share. Any party can spend the P2A output to attach a CPFP child with market-rate fees.

## BIP-68 nSequence Encoding

The nSequence field encodes relative timelocks per BIP-68:

```
Bit 31 (disable flag):  0 = relative timelock enforced, 1 = no relative timelock
Bit 22 (type flag):     0 = blocks, 1 = 512-second intervals
Bits 16-21, 23-30:      reserved (no consensus meaning)
Bits 0-15 (value):      relative lock-time in blocks or 512-second intervals
```

The DW delay values are parameterized at factory construction. Example values for `step_blocks=144, states_per_layer=4`:

| Value | nSequence (hex) | Meaning |
|-------|----------------|---------|
| Disabled | `0xFFFFFFFF` | No relative timelock (kickoff nodes) |
| 432 blocks | `0x000001B0` | ≈3 day delay (DW starting value) |
| 288 blocks | `0x00000120` | ≈2 day delay |
| 144 blocks | `0x00000090` | ≈1 day delay |
| 0 blocks | `0x00000000` | No delay (DW final value) |

## Witness Structure

### Key-Path Spend (Normal Operation)
```
witness:
  <64-byte Schnorr signature>
```

A single 64-byte Schnorr signature — indistinguishable from any other Taproot key-path spend.

### Script-Path Spend (LSP Timeout Recovery)
```
witness:
  <64-byte Schnorr signature>    ← signed by LSP's key
  <script bytes>                 ← the CLTV timeout script
  <control block>                ← leaf_version | internal_key | merkle_path
```

The script-path witness is larger than a key-path spend. It is only required when the cooperative (key-path) signing path is unavailable.

### Script-Path Spend (L-stock CSV drain)
```
witness:
  <64-byte Schnorr signature>    ← signed by LSP's key
  <script bytes>                 ← <csv> CSV DROP <LSP> CHECKSIG
  <control block>                ← leaf_version | internal_key (33 bytes)
```

The LSP's unilateral fallback for draining its own L-stock, gated by the CSV delay. The delay gives the client and watchtower time to broadcast the matching pre-signed [[l-stock-redistribution|redistribution TX]] (key-path) if the LSP is publishing a stale leaf state.

## Related Concepts

- [[decker-wattenhofer-invalidation]] — How nSequence values encode the state machine (interior layers)
- [[pseudo-spilman-leaves]] — TX chaining at the leaves
- [[l-stock-redistribution]] — Pre-signed redistribution TX co-signed at every state advance
- [[tapscript-construction]] — How script trees and control blocks are built
- [[musig2-signing-rounds]] — How the key-path signatures are created
- [[force-close]] — When these transactions actually hit the blockchain
