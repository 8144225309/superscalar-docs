# First Implementation Status

> **TLDR**: This is the first public implementation of SuperScalar. The original designer (ZmnSCPxj) published a design-only proposal in September 2024 with zero code. No other public implementations, prototypes, or proof-of-concepts exist as of February 2025.

## The Timeline

| Date | Event | Code? |
|------|-------|-------|
| **Sept 16, 2024** | ZmnSCPxj publishes SuperScalar design on Delving Bitcoin | No — design only |
| **Oct 2024** | Bitcoin Optech podcast deep dive with ZmnSCPxj | No — "no prototype exists yet" |
| **Nov 2024** | Pluggable channel factories thread on Delving Bitcoin | No — theoretical extensions |
| **2024-2025** | This repository: first production implementation | **Yes** |

## What ZmnSCPxj Published

ZmnSCPxj's original Delving Bitcoin post was a **design proposal** — a detailed technical specification with ASCII diagrams and protocol descriptions, but explicitly zero code. The 31-post thread that followed was entirely theoretical discussion.

From the project's own `RESEARCH.md`:

> *"SuperScalar (ZmnSCPxj, Delving Bitcoin Sept 2024) is design-only, zero code. We are the first implementation."*

## What Others Have Done

### ZmnSCPxj (Designer)
- Published the design on Delving Bitcoin
- Discussed it on the Bitcoin Optech podcast (October 2024)
- Proposed pluggable factory protocol extensions (November 2024)
- **Has not published any implementation code** — his GitHub repos include various Bitcoin/Lightning projects but no SuperScalar implementation

### Ark Labs
- Building a different protocol (Ark) with a different trust model (semi-custodial ASP)
- **Not a SuperScalar implementation** — different design entirely
- See [[comparison-to-ark]]

### Academic Papers
- Burchert, Decker & Wattenhofer (2017): Channel factories paper — theoretical, no implementation
- Various follow-ups on multi-party channels (2019, 2023) — none implement SuperScalar specifically

### Bitcoin Optech
- Covered SuperScalar in their podcast and newsletter
- Explicitly noted "no prototype exists yet" as of October 2024

## What This Implementation Covers

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1: DW Factory Tree** | Complete | 6-node alternating kickoff/state tree, MuSig2 signing, DW odometer |
| **Phase 2: Timeout-Sig-Trees** | Complete | CLTV timeout scripts, Taproot key+script paths, regtest verification |
| **Phase 3: Poon-Dryja Channels** | Future | Standard LN channels at factory leaves |
| **Phase 4: PTLC Key Turnover** | Future | Atomic private key handover for assisted exit |
| **Phase 5: Laddering** | Future | Factory rotation with staggered lifetimes |

## Shipping Target

Testnet deployment and public release — proving that SuperScalar is not just a theoretical design but a working protocol on Bitcoin.

## Related Concepts

- [[history-and-origins]] — The full history of the ideas behind SuperScalar
- [[why-superscalar-exists]] — The problem this solves
- [[pluggable-factories]] — Protocol extensions proposed but not yet implemented anywhere
