# MuSig2 Signing Rounds (Deep Dive)

> **TLDR**: The complete cryptographic protocol for producing a single Schnorr signature from N signers, including key aggregation, nonce commitment, partial signatures, and Taproot tweak integration.

## Prerequisites

- [[what-is-musig2]] — Conceptual overview
- [[what-is-taproot]] — Why tweaking matters

## The Full Protocol

### Step 0: Key Aggregation

Before any signing happens, participants aggregate their public keys:

```
Given: pubkeys P₁, P₂, ..., Pₙ

For each i:
  aᵢ = H("KeyAgg coefficient", P₁||P₂||...||Pₙ||Pᵢ)

Aggregate key: P = Σ(aᵢ × Pᵢ)
```

The coefficients `aᵢ` prevent a **rogue key attack** where a malicious signer could choose their pubkey to cancel out others.

The aggregate key `P` is what appears on-chain as the [[what-is-taproot|Taproot]] internal key.

### Step 1: Nonce Generation

Each signer generates **two** random nonce pairs (this is the "2" in MuSig2):

```
Signer i generates:
  (r₁ᵢ, R₁ᵢ) where R₁ᵢ = r₁ᵢ × G
  (r₂ᵢ, R₂ᵢ) where R₂ᵢ = r₂ᵢ × G

Sends (R₁ᵢ, R₂ᵢ) to all other signers
```

**Why two nonces?** A single nonce would allow a malicious signer who sees all other nonces first to choose their nonce to control the aggregate nonce. Two nonces are combined with a binding factor derived from the message, preventing this attack.

### Step 2: Nonce Aggregation

Once all public nonces are collected:

```
b = H("MuSig/noncecoef", R₁₁||R₂₁||...||R₁ₙ||R₂ₙ||P||message)

Aggregate nonce: R = Σ(R₁ᵢ) + b × Σ(R₂ᵢ)
```

The binding factor `b` ties the nonce aggregation to the specific message being signed.

### Step 3: Partial Signature

Each signer creates their partial signature:

```
e = H("BIP0340/challenge", R.x || P.x || message)

Signer i computes:
  sᵢ = aᵢ × (r₁ᵢ + b × r₂ᵢ + e × xᵢ)  mod n

where xᵢ is signer i's private key
```

### Step 4: Signature Aggregation

```
s = Σ(sᵢ) mod n

Final signature: (R.x, s)  — a standard 64-byte Schnorr signature
```

This signature is valid under the aggregate key `P` and is **indistinguishable** from a single-signer Schnorr signature.

## Taproot Tweaking

When the output has a [[what-is-taproot|script tree]], the on-chain key is tweaked:

```
t = H("TapTweak", P.x || merkle_root)
Q = P + t × G     ← this is the output key on-chain
```

The tweak must be incorporated during signing. In the implementation, this happens at nonce finalization:

```c
// Apply Taproot tweak to the signing session
musig_session_finalize_nonces(session, agg_nonce, message, taproot_tweak);
```

The tweaked signature is valid for `Q` (the output key), not `P` (the internal key).

## In the SuperScalar Codebase

```c
// Key aggregation
musig_aggregate_keys(pubkeys, n_pubkeys, &agg_key);

// Nonce generation (from pre-generated pool)
musig_nonce_pool_generate(pool, key, extra_input);
musig_generate_nonce(&secnonce, &pubnonce, pool);

// Session initialization
musig_session_init(&session, &agg_key);

// Collect pubnonces from all signers
musig_session_set_pubnonce(&session, i, &pubnonce_i);

// Finalize nonces (applies Taproot tweak if present)
musig_session_finalize_nonces(&session, taptweak);

// Create partial signature
musig_create_partial_sig(&session, &secnonce, &privkey, &partial_sig);

// Aggregate all partial signatures
musig_aggregate_partial_sigs(&session, partial_sigs, n_sigs, &final_sig);
```

## Nonce Pool Management

For a factory with 6 tree nodes, each signer needs at least 6 nonces (one per transaction to sign). In practice, pools are larger to accommodate state updates:

```c
#define NONCE_POOL_SIZE 64  // Pre-generate 64 nonces per signer
```

**Critical**: Nonces are **single-use**. The pool tracks which nonces have been consumed. Reusing a nonce across two different signing sessions would leak the signer's private key.

## Security Properties

| Property | Guarantee |
|----------|-----------|
| **Unforgeability** | No subset of <N signers can produce a valid signature |
| **Non-interactivity** | Only 2 rounds of communication needed |
| **Key aggregation** | On-chain key reveals nothing about individual signers |
| **Taproot compatibility** | Tweaked signatures work with BIP-341 script trees |
| **Nonce safety** | Two-nonce scheme prevents Wagner's attack on nonce aggregation |

## Related Concepts

- [[what-is-musig2]] — Conceptual overview
- [[building-a-factory]] — Where multi-session signing is coordinated
- [[tapscript-construction]] — How script trees integrate with MuSig2 keys
- [[transaction-structure]] — Where the final signatures end up
