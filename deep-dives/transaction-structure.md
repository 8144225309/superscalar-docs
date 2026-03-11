# Transaction Structure (Deep Dive)

> **Summary**: Every transaction in the SuperScalar factory tree is a standard Bitcoin transaction with specific version, nSequence, and witness fields that implement the DW mechanism, Taproot spending, and P2A fee-bumping.

## Transaction Types in the Factory

| Transaction | nVersion | nSequence | nLockTime | Witness |
|-------------|----------|-----------|-----------|---------|
| **Funding tx** | 2 | wallet default | 0 | LSP's regular spend |
| **Kickoff tx** | 2 | 0xFFFFFFFF (disabled) | 0 | MuSig2 key-path sig |
| **State tx** | 2 | BIP-68 relative delay | 0 | MuSig2 key-path sig |
| **Distribution tx** | 2 | 0xFFFFFFFF | nLockTime (inverted) | MuSig2 key-path sig |
| **Channel close** | 2 | varies (Poon-Dryja) | varies | Channel-specific |
| **Fee-bump child** | 2 | any | 0 | Spends P2A output |

### P2A Anchors and Fee-Bumping

P2A anchors appear on the **distribution transaction** and **channel commitment/penalty transactions** — not on tree node transactions (kickoff, state, leaf state). Tree transactions use endogenous fees baked in at signing time. The distribution tx's P2A anchor allows fee-bumping the final payout during force-close.

> **Future upgrade**: When the implementation migrates to `nVersion=3` (v3/TRUC policy, available since Bitcoin Core 28), P2A anchors can be reduced to 0 sats via the ephemeral dust exemption (Bitcoin Core 29). This is tracked as a future optimization.

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
│ Leaf State TX (e.g., state_left)            │
├─────────────────────────────────────────────┤
│ nVersion: 2                                 │
│ Input 0:                                    │
│   prev_txid: kickoff_left                   │
│   prev_vout: 0                              │
│   nSequence: 288 (DW Layer 1 delay)         │
│   witness: <64-byte MuSig2 signature>       │
│                                             │
│ Output 0: P2TR (Alice & LSP channel)        │
│   amount: channel capacity                  │
│   scriptPubKey: OP_1 <MuSig2(A, L)>        │
│                                             │
│ Output 1: P2TR (Bob & LSP channel)          │
│   amount: channel capacity                  │
│   scriptPubKey: OP_1 <MuSig2(B, L)>        │
│                                             │
│ Output 2: P2TR (LSP liquidity stock)        │
│   amount: remaining liquidity               │
│   scriptPubKey: OP_1 <L_tweaked>            │
│     script tree: hashlock (preimage reveal) │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

The leaf outputs are the actual Lightning channels and LSP liquidity stock. Channel outputs have no script tree (they use standard Poon-Dryja internally). The liquidity stock output includes a hashlock script-path leaf: anyone who reveals the 32-byte [[shachain-revocation|revocation secret]] preimage can spend it. The burn transaction directs the full value to an `OP_RETURN` output, making the funds unspendable — the entire amount becomes miner fees.

### L-Stock Hashlock Script

```
OP_SIZE OP_PUSHBYTES_1 0x20 OP_EQUALVERIFY OP_SHA256 OP_PUSHBYTES_32 <hash> OP_EQUAL
```

This verifies only that the witness provides a 32-byte value whose SHA256 matches the committed hash. No signature is required — anyone who knows the preimage can spend it. The preimage is the revocation secret revealed by the LSP when advancing to a new epoch.

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
| 432 blocks | `0x000001B0` | ~3 day delay (DW starting value) |
| 288 blocks | `0x00000120` | ~2 day delay |
| 144 blocks | `0x00000090` | ~1 day delay |
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

### Script-Path Spend (L-Stock Burn)
```
witness:
  <32-byte preimage>             ← the revocation secret
  <script bytes>                 ← the hashlock script (37 bytes)
  <control block>                ← leaf_version | internal_key (33 bytes)
```

No signature required. The preimage is the revocation secret for the epoch being punished. The spending transaction sends all funds to `OP_RETURN` (miner fees).

## Related Concepts

- [[decker-wattenhofer-invalidation]] — How nSequence values encode the state machine
- [[tapscript-construction]] — How script trees and control blocks are built
- [[musig2-signing-rounds]] — How the key-path signatures are created
- [[force-close]] — When these transactions actually hit the blockchain
- [[shachain-revocation|Revocation Secrets]] — The hashlock preimage mechanism for L-stock punishment
