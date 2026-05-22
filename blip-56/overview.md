# BLIP-56 Integration

[BLIP-56](https://github.com/lightning/blips/pull/56) (Pluggable Channel Factories) is a Lightning Network spec extension that allows channel-factory plugins to coexist with existing Lightning implementations (CLN, LDK, LND, Eclair) without modifying the core channel-management code.

## Why pluggable factories

The motivation, from ZmnSCPxj's [Pluggable Channel Factories thread (Delving t/1252)](https://delvingbitcoin.org/t/pluggable-channel-factories/1252):

Existing Lightning implementations already handle channel management, HTLC forwarding, fee negotiation, and timelock enforcement. A channel factory introduces a **new layer underneath** — the factory tree — but the channels at the leaves should work exactly like normal Lightning channels.

BLIP-56's design intent: let factory logic live in a **plugin**, with the LN node delegating factory-specific behavior via TLV signaling. Channels appear as "0-conf" channels with funding TX never broadcast; the plugin manages the actual factory state.

## The three load-bearing changes

### 1. Feature bit 271 `pluggable_channel_factories`

Advertised in `init` and `node_announcement`. Odd (optional). Nodes that don't understand it can ignore peer messages.

### 2. TLV 65600 `channel_in_factory` on `open_channel`

```
factory_protocol_id          (32 bytes)
factory_instance_id          (32 bytes)
factory_early_warning_time   (u16)
```

The `factory_protocol_id` distinguishes SuperScalar from other (future) factory protocols.

Channels opened with this TLV MUST:
- Use `option_zeroconf` channel type
- Set HTLC `cltv_expiry ≥ current block + factory_early_warning_time + 1`
- Defer `channel_ready` until factory plugin completes setup
- NOT broadcast funding TX directly
- Raise early-warning events when HTLCs approach factory timeout

### 3. Custommsg 32800 `factory_message_id`

Wraps all factory plugin-to-plugin messages. Body is `factory_submessage_id` (u16) + submsg payload.

## The `factory_early_warning_time` parameter

This is critical for safety. Factory-hosted channels have an extra constraint: all HTLCs must resolve **before** the factory's CLTV timeout expires. If an HTLC is still pending when the factory times out, the LSP can exercise the timeout path and sweep the factory output, forfeiting any in-flight HTLC value that should have resolved in the client's favor.

```
HTLC creation ──[cltv_expiry buffer]──► HTLC must resolve ──[factory_early_warning_time]──► Factory CLTV timeout
```

The `factory_early_warning_time` value inflates both:
- `min_final_cltv_expiry` in BOLT 11 invoices (for the final hop)
- `cltv_expiry_delta` announced in `channel_update` messages (for routing)

This ensures all HTLCs resolve before the factory's CLTV timeout.

## Splice-style state transitions

BLIP-56 reuses splicing primitives. Channels in a factory go through state changes (factory tree advances) that look like splicing under the hood — funding outpoint changes while the channel stays live, with batch `commitment_signed` messages supporting dual states.

Per t/1252:

> *"Reuses splicing infrastructure because both deal with: changing funding outpoints and maintaining multiple simultaneously-valid outpoints during transitions."*

The flow: STFU quiescence → factory state transition messages → multiple `commitment_signed` with batch TLVs supporting dual states → resolution messages confirming new outpoint.

## The full stack

Three repositories make up the SuperScalar BLIP-56 stack:

- **[github.com/8144225309/cln-blip56](https://github.com/8144225309/cln-blip56)** — Fork of Core Lightning carrying the BLIP-56 wire baseline (feature bit 271, TLV 65600, custommsg 32800).
- **[github.com/8144225309/superscalar-cln](https://github.com/8144225309/superscalar-cln)** — CLN plugin that runs the SuperScalar-specific factory protocol on top of cln-blip56.
- **[github.com/8144225309/superscalar-wallet](https://github.com/8144225309/superscalar-wallet)** — End-user wallet that speaks to the plugin.

See each repository's README for current build instructions and status.

## Out of scope (current)

Per the BLIP-56 design:
- **BOLT 7 gossip extensions** for factory channels — separate effort needed before factory channels can be publicly routed via gossip
- **Multi-factory client management** at the LN node level — currently handled at plugin/wallet layer

## Why a BLIP, not a BOLT

A BLIP (Bitcoin Lightning Improvement Proposal) is the right vehicle for extensions that:
- Don't require changes to all Lightning implementations to interoperate
- Use plugin/extension mechanisms each implementation already has
- May be experimental or specialized

Once BLIP-56 stabilizes and multiple factory protocols implement it, the framework could graduate to a BOLT. For now, BLIP is the appropriate spec layer.

## Related

- BLIP-56 PR: <https://github.com/lightning/blips/pull/56>
- ZmnSCPxj's Pluggable Channel Factories thread: <https://delvingbitcoin.org/t/pluggable-channel-factories/1252>
- [[pseudo-spilman-leaves]] — what the factory mechanism is, beneath the wire layer
- [[updating-state]] — how the splice-style state transitions are used
