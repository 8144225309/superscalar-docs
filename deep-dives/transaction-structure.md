# Transaction Structure (Deep Dive)

> **Summary**: Every transaction in the SuperScalar factory tree is a standard Bitcoin transaction with specific version, nSequence, and witness fields that implement the DW mechanism, Taproot spending, and P2A fee-bumping.

## Transaction Types in the Factory

| Transaction | nVersion | nSequence | nLockTime | Witness |
|-------------|----------|-----------|-----------|---------|
| **Funding tx** | 2 | wallet default | 0 | LSP's regular spend |
| **Kickoff tx** | 3 (v3 policy) | 0xFFFFFFFF (disabled) | 0 | MuSig2 key-path sig |
| **State tx** | 3 (v3 policy) | BIP-68 relative delay | 0 | MuSig2 key-path sig |
| **Channel close** | 2 | varies (Poon-Dryja) | varies | Channel-specific |
| **Fee-bump child** | 3 (v3 policy) | any | 0 | Spends P2A output |

### nVersion = 3 (v3 Transaction Policy)

Tree transactions use `nVersion=3`, which opts into Bitcoin Core 28's **TRUC (Topologically Restricted Until Confirmation)** policy. TRUC transactions are limited to one unconfirmed parent and one unconfirmed child, which enables ephemeral anchor outputs (0-sat P2A) and simplifies CPFP fee-bumping.

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
│     script tree = CLTV timeout for LSP      │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

On-chain, this output is indistinguishable from any other P2TR output. A cooperative key-path spend is indistinguishable from a single-signer Taproot spend.

## Kickoff Transaction

```
┌─────────────────────────────────────────────┐
│ Kickoff TX (e.g., kickoff_root)             │
├─────────────────────────────────────────────┤
│ nVersion: 3                                 │
│ Input 0:                                    │
│   prev_txid: funding tx                     │
│   prev_vout: 0                              │
│   nSequence: 0xFFFFFFFF (disabled)          │
│   witness: <64-byte MuSig2 signature>       │
│                                             │
│ Output 0: P2TR (for state tx)               │
│   scriptPubKey: OP_1 <tweaked_key>          │
│                                             │
│ Output 1: P2A (fee-bump anchor)             │
│   amount: 0 sats (ephemeral dust)           │
│   scriptPubKey: OP_1 <0x4e73>               │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

Key properties:
- `nSequence = 0xFFFFFFFF`: Relative timelock **disabled** — no delay after parent confirms
- Single MuSig2 signature in witness (key-path spend)
- P2A output for CPFP fee-bumping

## State Transaction

```
┌─────────────────────────────────────────────┐
│ State TX (e.g., state_root, epoch 2)        │
├─────────────────────────────────────────────┤
│ nVersion: 3                                 │
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
│ Output 2: P2A (fee-bump anchor)             │
│   amount: 0 sats (ephemeral dust)           │
│   scriptPubKey: OP_1 <0x4e73>               │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

Key properties:
- `nSequence = 144`: BIP-68 relative timelock requiring 144 blocks after the parent confirms. This delay decreases with each epoch per the [[decker-wattenhofer-invalidation|DW mechanism]].
- Each P2TR output includes a CLTV script-path leaf for [[timeout-sig-trees|LSP timeout recovery]].

## Leaf State Transaction

```
┌─────────────────────────────────────────────┐
│ Leaf State TX (e.g., state_left)            │
├─────────────────────────────────────────────┤
│ nVersion: 3                                 │
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
│     script tree: shachain secret path       │
│                                             │
│ Output 3: P2A (fee-bump anchor)             │
│   amount: 0 sats (ephemeral dust)           │
│   scriptPubKey: OP_1 <0x4e73>               │
│                                             │
│ nLockTime: 0                                │
└─────────────────────────────────────────────┘
```

The leaf outputs are the actual Lightning channels and LSP liquidity stock. Channel outputs have no script tree (they use standard Poon-Dryja internally). The liquidity stock output includes a script-path leaf that can be spent by revealing a shachain-derived secret, enabling [[shachain-revocation|revocation of outdated states]].

## BIP-68 nSequence Encoding

The nSequence field encodes relative timelocks per BIP-68:

```
Bit 31 (disable flag):  0 = relative timelock enforced, 1 = no relative timelock
Bit 22 (type flag):     0 = blocks, 1 = 512-second intervals
Bits 16-21, 23-30:      reserved (no consensus meaning)
Bits 0-15 (value):      relative lock-time in blocks or 512-second intervals
```

Examples used in SuperScalar:
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

## Related Concepts

- [[decker-wattenhofer-invalidation]] — How nSequence values encode the state machine
- [[tapscript-construction]] — How script trees and control blocks are built
- [[musig2-signing-rounds]] — How the key-path signatures are created
- [[force-close]] — When these transactions actually hit the blockchain
