# Backup & Recovery

> **Summary**: Self-custody is only real if a client can recover **without** the LSP. A SuperScalar client persists every pre-signed transaction it would need to exit, so even if the LSP vanishes forever the client can force-close its channel and sweep its funds on-chain from its own database plus its key. This page covers what the client stores, what to back up, and how recovery actually runs.

## The self-custody requirement

The core guarantee — *each client can always exit; the LSP cannot steal* — depends on the client physically holding the transactions that encode its exit path. If those were only on the LSP's side, "non-custodial" would be a fiction. So the client persists them locally as they are created.

## What the client persists

At factory construction and at every [[updating-state|state advance]], the client stores:

| Item | Why it's needed |
|------|-----------------|
| The **pre-signed tree path** from the funding UTXO down to its leaf (kickoff/state nodes) | To publish its branch on a unilateral exit |
| Its **latest leaf state TX** ([[pseudo-spilman-leaves\|pseudo-Spilman]] chain tip) | To bring its channel on-chain |
| Its **inner-channel commitment** (and the prior revocation secret) | Standard BOLT-2 close / penalty |
| The matching **[[l-stock-redistribution\|redistribution TX]]** for each state's L-stock | To claw back the LSP's stock if it publishes a stale state |
| The factory **CLTV timeout / distribution** transaction | The fallback that pays clients out after the absolute timeout |

The client holds a complete, self-contained exit kit — it does not need to ask the LSP for anything to leave.

### A subtle gap, now closed

Earlier, a channel's **initial** commitment was only persisted after its *first* payment. That left a hole: a brand-new, never-transacted channel had nothing on disk to force-close with if the LSP disappeared immediately. The current design persists the initial commitment at channel creation, so even a never-used channel is recoverable from the moment it exists.

## What to back up

Two things, and they are enough to reconstruct the exit kit:

1. **The client database** — the persisted transactions and channel state above.
2. **The client's key** (seed / keyfile) — used to sign the final channel close and to sweep recovered outputs.

The database is the bulky, frequently-changing part; the key is small and static. A backup of both, kept current, is a complete recovery package.

### At-rest protection

Because the database (and especially the seed) are sensitive, SuperScalar supports **at-rest encryption** of the secret material — the HD seed and secret columns are sealed so that a stolen database file alone does not hand an attacker the keys. (On mainnet, supplying a raw private key on the command line is refused outright, to avoid the most common foot-gun.)

## How recovery runs

### LSP vanished — force-close from the database

If the LSP is gone, the client drives the exit itself, entirely from its persisted state:

1. **Publish the tree path** — the kickoff/state transactions from the funding UTXO down to the client's leaf. Interior [[decker-wattenhofer-invalidation|DW]] layers impose their relative-timelock delays; the [[pseudo-spilman-leaves|PS]] leaf has none.
2. **Publish the latest leaf state** — bringing the client's channel on-chain.
3. **Close the channel** — a standard Poon-Dryja close of the on-chain channel.
4. **Sweep** the resulting output to a wallet the client controls, signed with the client's key.

This is a **topological, multi-pass** process — outputs become spendable in dependency order as their parents confirm and timelocks mature — so recovery proceeds in rounds rather than a single transaction.

### Mass exit

If many clients in a factory must exit at once (e.g., the LSP shuts down), each runs the same self-exit independently. The [[force-close]] page covers the per-client cost and the blast-radius limits that keep one client's exit from forcing everyone else on-chain.

### After the absolute timeout

Even a client that has lost its database has a backstop: the pre-signed CLTV **distribution transaction** pays the clients out once the factory's timeout height is reached, and any party holding a copy can broadcast it. This is the last line of defense, not the primary path.

## Related Concepts

- [[pseudo-spilman-leaves]] — The leaf state the client publishes to bring its channel on-chain
- [[l-stock-redistribution]] — The pre-signed claw-back the client also persists
- [[watchtower]] — Watches on the client's behalf while it is offline (complementary to self-recovery)
- [[force-close]] — The full unilateral-exit walkthrough and its costs
- [[timeout-sig-trees]] — The CLTV distribution backstop
- [[security-model]] — Why self-custody is the central property
