# Roadmap

> **Summary**: SuperScalar is a working prototype with a clear path to production deployment. The reference implementation demonstrates the full protocol stack today; the roadmap focuses on specification, hardening, integration, and tooling for real-world LSP operation.

## Current State

The reference implementation is written in C and covers the complete protocol:

| Component | Status |
|---|---|
| Factory construction (N-of-N MuSig2 tree signing) | Working |
| Leaf Lightning channels (Poon-Dryja) with HTLC routing | Working |
| Force close / unilateral exit | Working |
| Revocation (punishment for stale state) | Working |
| PTLC assisted exit (key turnover) | Working |
| Factory laddering with auto-rotation | Working |
| Watchtower (old-state monitoring + penalty broadcast) | Working |
| Sub-1-sat/vB fee support with automatic P2A anchor control | Working |

461 tests (418 unit + 43 regtest), CI on Linux, macOS, and ARM64. Source: [github.com/8144225309/SuperScalar](https://github.com/8144225309/SuperScalar).

---

## Phase 1 — Protocol Specification

**Formal Protocol Specification**

The protocol is currently defined by implementation and documentation. A formal specification — BOLT-style, defining all message types, state machine transitions, transaction formats, and signing protocols — is required for independent implementations, security review, and standardization.

- Wire protocol messages for factory construction, state updates, and client migration
- Formal state machine for each participant role (LSP, client, watchtower)
- Transaction format specification with test vectors
- Signing round protocol with edge case handling and failure modes

---

## Phase 2 — Production Hardening

**State Persistence & Recovery**

Production deployments require robust state management: crash recovery, backup and restore, and safe re-entry after unexpected shutdown. The current implementation handles the cooperative path; production requires handling all failure modes without loss of funds.

- Atomic state transitions with write-ahead logging
- Client-side backup protocol for the pre-signed transaction set
- Recovery procedure for mid-protocol failures (partial signing rounds)
- State audit tooling for LSP operators

**C Library / SDK**

A clean SDK separates the protocol library from the test harness and exposes a stable API for LSP and wallet integration:

- Public API surface with documented ABI
- Packaging for Linux, macOS, and ARM64
- Language bindings (Python, Rust FFI)
- Integration guide for LSP operators

---

## Phase 3 — Integration

**Pluggable Factory Protocol**

For SuperScalar to coexist with standard Lightning implementations (CLN, LND, LDK, Eclair), a TLV-based protocol extension allows factory-hosted channels to be managed by a plugin without modifying core LN software. Includes the `blocks_early` parameter ensuring all HTLCs resolve before factory CLTV timeout.

**Trustless Watchtower Protocol**

The current watchtower requires trust or runs within the LSP. A trustless design allows third-party operators to monitor and penalize old-state broadcasts without holding client funds or private keys:

- Encrypted breach remedy transaction delivery to watchtower
- Payment-for-service model (watchtower earns a portion of recovered funds)
- Multi-tower redundancy for resilience against watchtower failure

---

## Phase 4 — Client Tooling

**Reference Wallet**

A minimal reference wallet demonstrating the full client-side flow:

- Factory enrollment and channel receipt with zero on-chain Bitcoin
- Lightning payments (send and receive)
- Factory rotation (background, no user action required)
- Force-close and fund recovery

**LSP Operator Tooling**

Dashboard and CLI tools for LSP operators managing laddered factory deployments: capital utilization, client status, rotation scheduling, and fee rate monitoring.

---

## Phase 5 — Open Research

**Coordination Layer**

The hardest unsolved problem in SuperScalar deployment: how do clients who do not know each other form UTXO-sharing relationships safely and trustlessly?

Clients must agree on factory membership, contribution sizes, and signing schedules. A naive approach trusts the LSP to assign clients to factories — which is practical but requires trusting the LSP not to stack factories with sockpuppet accounts. A fully trustless approach requires P2P coordination without a central authority.

The design space includes:

- **LSP-coordinated matchmaking** — centralized, practical, the likely first deployment model
- **P2P gossip / DHT-based discovery** — fully trustless, high coordination complexity
- **Reputation-based grouping** — semi-decentralized, requires persistent identity

The coordination layer determines whether factory formation becomes as seamless as opening a standard Lightning channel, and how resistant it is to Sybil attacks and group manipulation. This work is ongoing.

---

## Related Concepts

- [[network-economics]] — Cost model and capital efficiency of deployed factories
- [[laddering]] — The rotation lifecycle the roadmap builds around
- [[security-model]] — Current threat model and open problems
- [[soft-fork-landscape]] — Covenant upgrades that could affect the roadmap
