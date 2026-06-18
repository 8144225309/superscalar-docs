# Detecting LSP Misbehavior

> **Summary**: The N-of-N multisig already means the LSP *cannot* steal. This page covers the layer above that: how a client **detects** an LSP that is *trying* to cheat — for example forging a revocation — and how it **escalates** in response, from logging-and-continuing all the way to force-closing the affected channel. Detection is the real defense; the on-chain penalties are the backstop.

## Why detection matters even with N-of-N

A dishonest LSP can't move funds unilaterally, but it can still *attempt* things that, if a client blindly went along with them, would weaken the client's position — most importantly, sending a **forged or invalid revocation** to make the client believe an old state is safely revoked when it is not. The client's protection is to **verify, fail-closed, and escalate**: never accept a revocation it cannot check, and react proportionally when a check fails.

## Verifying revocations (fail-closed)

Every time the LSP claims to revoke a prior state, the client **independently verifies** that the revocation is valid before treating the old state as dead. If verification fails — the revocation is malformed, doesn't correspond to the committed state, or can't be checked — the client treats it as **misbehavior**, not as a transient glitch. "Fail-closed" means the ambiguous case is treated as hostile, never waved through.

This closes the gap where a client might otherwise advance its state on the LSP's say-so without confirming the LSP actually gave up the ability to publish the old one.

## Escalation policy

Detection on its own isn't enough — the client has to *do* something, and how aggressive that should be depends on the deployment. SuperScalar makes the response a **configurable policy** (`--on-lsp-forgery`) with three levels:

| Mode | Behavior on detected forgery | When to use |
|------|------------------------------|-------------|
| `continue` | Log loudly, refuse the bad message, keep the channel open | Maximum availability; you accept manual follow-up |
| `halt` *(default)* | Stop transacting with the LSP and stop auto-reconnecting; wait for operator review | Safe default — freeze, don't gamble |
| `close` | Proactively force-close to get on-chain immediately | Lowest risk tolerance; exit at the first sign of cheating |

The default is **`halt`**: on detecting forgery the client neither keeps trusting the LSP nor immediately pays the cost of a force-close — it freezes and surfaces the event.

### Per-leaf-type severity

Not every channel faces the same urgency. A [[pseudo-spilman-leaves|pseudo-Spilman]] leaf is CLTV-gated and structurally ordered, so an old state can't be resurrected by a race — there is more time to react. The escalation can therefore be **tuned by leaf type**, treating the structurally-safer PS leaves as less urgent than situations with a tighter timelock race.

### Surgical close

When the response is to close, it can be **scoped to the affected channel** rather than tearing down the client's whole factory position. A single misbehaving interaction shouldn't force every one of a client's channels on-chain if only one is implicated.

## The poisoned-LSP marker

A subtle failure mode: a client detects forgery, halts — and then **restarts** and cheerfully reconnects to the same LSP as if nothing happened. To prevent that, detection writes a **persistent "poisoned" marker** for that LSP. After a restart the client sees the marker and **does not auto-reconnect**, so the freeze survives a reboot and requires a deliberate operator decision to clear.

## Detection is the defense; penalties are the backstop

It's worth being explicit about the ordering:
- **Detection + escalation** (this page) is what keeps a client from being *maneuvered* into a weak position in the first place.
- The on-chain **[[watchtower|watchtower]] penalties** and **[[l-stock-redistribution|redistribution TX]]** are what make cheating *unprofitable* if the LSP actually broadcasts something stale.

The same philosophy shows up elsewhere in the protocol — for instance, just-in-time channels are protected by **registering the factory leaf for watching** (so a breach is detected and penalised) rather than by assuming a penalty broadcast alone.

## Related Concepts

- [[watchtower]] — The on-chain backstop that penalises a cheat that's actually broadcast
- [[shachain-revocation]] — The inner-channel revocation whose forgery this detects
- [[l-stock-redistribution]] — The economic penalty for a stale L-stock broadcast
- [[client-recovery]] — What `close` ultimately relies on to get funds out
- [[security-model]] — The threat model these responses sit within
