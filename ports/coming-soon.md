# LDK and LND ports — Coming soon

The reference implementation lives in C and integrates with [Core Lightning (CLN)](https://github.com/ElementsProject/lightning) via the [CLN fork (`blip-56` branch)](https://github.com/8144225309/lightning/tree/blip-56) + [`superscalar-cln`](https://github.com/8144225309/superscalar-cln) plugin, all coordinated through the BLIP-56 wire protocol. The same wire protocol is designed to support [LDK](https://github.com/lightningdevkit/rust-lightning) and [LND](https://github.com/lightningnetwork/lnd) — but those ports are not yet built.

## LDK port

**Status:** coming soon.

**Why it matters.** [Lightning Dev Kit (LDK)](https://lightningdevkit.org/) is a Rust library used by mobile wallets (Mutiny, Riot, etc.) and self-hosted nodes. Many would-be SuperScalar clients live in LDK-based wallets, not on a full CLN node.

**Approach.** The LDK port reuses the BLIP-56 wire layer (TLV 65600 / custommsg 33001 / feature bit 270/271 / submsg dispatch) and the on-chain primitives (L-stock SPK, redistribution TX, PS chain extension). The LDK port surface is the factory client side — the LSP side remains on CLN for now.


Tracking: [github.com/8144225309/SuperScalar/issues](https://github.com/8144225309/SuperScalar/issues) (open an issue if you want to contribute).

## LND port

**Status:** coming soon.

**Why it matters.** [LND](https://github.com/lightningnetwork/lnd) is the most-deployed Lightning node in production. SuperScalar support in LND would let existing LND operators run as either factory clients or, eventually, as LSPs.

**Approach.** LND does not have a native plugin system equivalent to CLN's, so the LND port involves either a sidecar process speaking BLIP-56 over LND's gRPC, or a fork carrying the necessary protocol changes. Both paths are under consideration.


Tracking: [github.com/8144225309/SuperScalar/issues](https://github.com/8144225309/SuperScalar/issues).

## Eclair

[Eclair](https://github.com/ACINQ/eclair) (the ACINQ implementation behind Phoenix wallet) is also a candidate. Coordination with ACINQ would be the gating factor.

## What you can do today

While LDK/LND ports are pending, you can run SuperScalar today with:

- **A real CLN node** running the [CLN fork (`blip-56` branch)](https://github.com/8144225309/lightning/tree/blip-56) + `superscalar-cln` plugin (LSP or client side)
- **The standalone reference implementation** (`superscalar_lsp` + `superscalar_client` binaries) on regtest, signet, or testnet4 — this is what the signet exhibition campaigns use

See the reference implementation's README for build + run instructions on regtest.

## References

- [BLIP-56 PR](https://github.com/lightning/blips/pull/56) — the wire protocol all ports implement
- [LDK GitHub](https://github.com/lightningdevkit/rust-lightning)
- [LND GitHub](https://github.com/lightningnetwork/lnd)
- [Eclair GitHub](https://github.com/ACINQ/eclair)
