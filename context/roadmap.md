# Roadmap

> **Summary**: SuperScalar covers the complete protocol stack today across three repositories — the C reference implementation, a CLN fork carrying the BLIP-56 wire layer, and a CLN plugin that runs SuperScalar logic on top. A user-facing wallet is the fourth piece. This page lists where each lives and what's next.

## The full stack today

| Repo | Role | What it does |
|---|---|---|
| **[github.com/8144225309/SuperScalar](https://github.com/8144225309/SuperScalar)** | Reference implementation (C) | LSP + standalone watchtower + reference client. Contains the factory tree builder, MuSig2 wire ceremonies, L-stock + redistribution TX, whole-tree refresh, sub-factory chain extension, mixed-arity / static-near-root tree shaping, and the regtest / signet exhibition test suite. |
| **[github.com/8144225309/lightning (branch `blip-56`)](https://github.com/8144225309/lightning/tree/blip-56)** | CLN fork (BLIP-56 wire layer) | Fork of Core Lightning carrying the BLIP-56 baseline: feature bit 270/271, TLV 65600 `channel_in_factory` on `open_channel`, custommsg 33001 dispatch. See [[blip-56-integration|BLIP-56 Integration]]. |
| **[github.com/8144225309/superscalar-cln](https://github.com/8144225309/superscalar-cln)** | CLN plugin | Runs the SuperScalar-specific factory protocol on top of the CLN fork. Provides the factory-join lifecycle, ceremony coordination, and the RPCs a wallet talks to. |
| **[github.com/8144225309/superscalar-wallet](https://github.com/8144225309/superscalar-wallet)** | End-user wallet | React/Node wallet for joining factories, sending/receiving Lightning, and handling factory rotation. |

If you want to try the full stack, clone all four. The reference implementation alone is enough for a regtest demo — see its README for build + run instructions.

## Current state (reference implementation)

| Component | Status |
|---|---|
| Factory construction (N-of-N MuSig2 tree signing) | Working |
| Pseudo-Spilman leaves (canonical leaf mechanism) | Working |
| L-stock SPK + per-client redistribution TX (canonical, t/1242) | Working |
| Mixed-arity interior + static-near-root tree shapes | Working (verified to N=128) |
| Whole-tree CLTV refresh (in-place rotation) | Working |
| Sub-factory k² PS chain extension | Working |
| Force close / unilateral exit | Working |
| PTLC assisted exit (key turnover) | Working |
| Factory laddering with auto-rotation | Working |
| Standalone watchtower (old-state monitoring + penalty broadcast) | Working |
| Sub-1-sat/vB fee support with automatic P2A anchor control | Working |
| BLIP-56 wire integration (CLN fork + superscalar-cln plugin) | Working |

1377 unit + 42 regtest + 30 signet exhibition tests, CI on Linux, macOS, and ARM64.

## What's next

The protocol stack is feature-complete for what's been designed; the remaining work is hardening, ecosystem fit, and unsolved-research items.

### Hardening

- **State persistence + recovery** — crash recovery, backup and restore, safe re-entry after unexpected shutdown across all four ceremonies (per-leaf advance, per-leaf realloc, sub-factory advance, whole-tree refresh).
- **Operator tooling** — dashboards and CLI for managing laddered factory deployments: capital utilization, per-client status, rotation scheduling, fee-rate monitoring.
- **Independent review** — the protocol benefits from outside scrutiny; pursuing free / community review channels.

### Ecosystem ports

LDK and LND ports are coming soon — see [[ports/coming-soon|Ecosystem Ports]] for the current status of each.

### Trustless watchtower

A trustless watchtower lets third-party operators monitor and penalize old-state broadcasts without holding any client-coupled state. Design properties:

- Encrypted breach-remedy delivery to watchtower
- Payment-for-service model (watchtower earns a portion of recovered funds)
- Multi-tower redundancy for resilience against watchtower failure

Being built before release.

---

## Related

- [[blip-56-integration|BLIP-56 Integration]] — wire protocol layer (CLN fork details)
- [[network-economics]] — Cost model and capital efficiency
- [[laddering]] — The rotation lifecycle the roadmap builds around
- [[security-model]] — Current threat model
- [[l-stock-redistribution]] — Canonical cheating-recovery mechanism (replaces older t/1143 burn)
- [[soft-fork-landscape]] — Covenant upgrades that could affect the roadmap
