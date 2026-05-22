# Revocation Secrets (Inner BOLT-2 Channels)

> **Summary**: Each leaf in a SuperScalar factory carries a standard bidirectional BOLT-2 Lightning channel on top. That inner channel uses standard Lightning revocation: when the channel state advances, the previous state's revocation secret is shared, so a counterparty broadcasting an old commitment can be penalized via the standard Poon-Dryja mechanism. This page covers how those revocation secrets are generated and managed.

> **Note on scope:** Revocation secrets here apply **only** to the inner BOLT-2 channels. The leaf-level state (the pseudo-Spilman chain) is non-revocable by design — see [[pseudo-spilman-leaves]] — and the LSP's liquidity stock has its own cheating-recovery mechanism described in [[l-stock-redistribution]]. Neither of those uses revocation secrets.

## What revocation secrets do

A BOLT-2 Lightning channel between a client and the LSP carries a commitment transaction that represents the current channel state. When the state advances (after every payment, splice, or other channel-level update), the prior commitment is revoked: each party shares the revocation secret for the prior state with the other party.

If either party later broadcasts that revoked commitment, the counterparty can use the revealed secret to construct a penalty transaction that sweeps the cheater's funds. This is the standard Poon-Dryja penalty mechanism; it's not specific to SuperScalar.

## Where the secrets come from

Two methods are available for generating revocation secrets:

### Flat secrets (preferred for multi-signer endpoints)

Each commitment gets an **independent random 32-byte secret**. The endpoint pre-generates the secret stream and pre-computes its hashes; the secrets stream out over the lifetime of the channel.

Storage cost is small (32 bytes per revocation, accumulated as the channel advances) and it has an important property at SuperScalar's scale: each secret can be generated through a multi-party process where multiple signers each contribute randomness. That matters because Lightning channels in a SuperScalar leaf are signed by a MuSig2 cohort, not a single device — so a derivation that requires a single device to hold the whole secret stream isn't a fit.

ZmnSCPxj on this point ([Delving Bitcoin, t/1143, post #34](https://delvingbitcoin.org/t/superscalar-laddered-timeout-tree-structured-decker-wattenhofer-factories/1143)):

> *"there is no multi-participant method of creating shachain ... having a single device perform the shachain in full is not truly multisignature."*

### Shachain (legacy)

A compact secret-derivation tree from BOLT #3 that derives 2⁴⁸ unique secrets from a single 32-byte seed. It has small constant storage but it's a single-party derivation — one device holds the seed and produces the whole stream. That's a fine fit for single-key Lightning endpoints (the original target of shachain) but it doesn't compose with multi-signer endpoints inside SuperScalar leaves.

The implementation retains shachain support behind a flag for compatibility with peers that don't speak the multi-party flat-secrets generation.

## Why "burn to fees" isn't used here

Earlier writeups of SuperScalar described a hashlock-based "L-stock burn" mechanism where a revocation-secret reveal would let anyone burn the LSP's liquidity stock to miner fees. That was the t/1143 design. The current canonical design replaces that mechanism with the L-stock SPK + pre-signed redistribution TX described in [[l-stock-redistribution]] — clients get the LSP's stake as recoverable outputs, not burned fees.

Revocation secrets in current SuperScalar are therefore scoped to the **standard Lightning channel** mechanism, exactly as they work in any non-factory Lightning channel.

## Related Concepts

- [[pseudo-spilman-leaves]] — The non-revocable leaf-level mechanism that sits underneath the BOLT-2 channels
- [[l-stock-redistribution]] — The canonical mechanism for protecting the LSP's liquidity stock (replaces the older t/1143 burn)
- [[what-is-an-lsp]] — Why the LSP runs the channel side that holds revocation secrets
