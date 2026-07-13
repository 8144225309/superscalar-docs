# SuperScalar off-chain: payments, state, and scale

The [signet exhibition](#deep-dives/signet-exhibition) is the **on-chain** story — the handful of transactions a factory writes to Bitcoin across its whole life. This page is the other half: the **off-chain** layer, where SuperScalar actually does its work, and the numbers a real run produced there.

## Why almost nothing is on-chain

A SuperScalar factory pools many Lightning channels behind a **single P2TR UTXO** — an N-of-N MuSig2 output of the LSP and up to 127 clients. Once that UTXO is funded, the base layer is out of the loop:

- **Channels** — each client holds a pseudo-Spilman channel *inside* the factory tree; it carries HTLCs exactly like an ordinary Lightning channel.
- **Payments** — routed through those channels as off-chain HTLCs. They move balance between participants and leave **no transaction on the chain**.
- **State updates** — a new set of balances is agreed by the participants **re-signing** the relevant transactions; the superseded state is invalidated by a *shortening relative-timelock* — the Decker–Wattenhofer "odometer," where a newer state can always be published ahead of a stale one. Re-signing settles nothing on-chain; the funds stay pooled in the one UTXO.
- **Liquidity on demand** — if a client needs inbound it doesn't yet have, the LSP can open a just-in-time channel for it without rebuilding the factory.

Balances only *become* on-chain sats at a **close** — cooperative (one aggregated transaction) or unilateral (a client broadcasts its own branch of the tree). Everything between funding and close happens off-chain.

## What the flagship run carried

The design-maximum factory in the exhibition (Exhibit 1) didn't hold a static balance — it carried real traffic:

| metric | value |
|---|---|
| Clients behind one UTXO | **127** (design maximum; 128 signers) |
| Real Lightning payments routed | **99**, over a ~24-hour soak |
| Payment source | an unmodified, **non-bLIP-56 CLN node**, via the bridge |
| On-chain transactions for all of it | **2** — one funding, one close |

## The scale economy

That last row is the point of the whole design: **127 channels opened, used, and closed with a two-transaction on-chain footprint** — the funding ([`143471b5…`](https://mempool.space/signet/tx/143471b5d1ddc0eee3ea54d74ed17081f24d48f429bb826723c8b0897e55c0e6)) and the aggregated close ([`0ca6b929…`](https://mempool.space/signet/tx/0ca6b929e2d7a52633b33d3a0a36f531d6230f49ffccbac7486977d745aa1056)).

Done as individual Lightning channels, the same 127 would cost roughly **254** on-chain transactions — an open and a close each. A factory collapses that to **one shared open and one aggregated close**, regardless of how many clients it holds. The base-layer cost is broadly constant in the number of channels; the off-chain layer is where they scale.

## An honesty note on these numbers

The exhibition's transactions are independently verifiable — every txid is on-chain, inspectable by anyone. **The off-chain figures on this page are not, and by their nature can't be:** off-chain activity leaves no transaction, so the payment count and soak duration come from the LSP's own logs, not from Bitcoin. The one number here you *can* verify is the on-chain count — the two transactions linked above.

For the trust model underneath all of this — why a client never has to rely on the LSP or on the other clients — see [*Cooperation is an optimization, not a requirement*](#deep-dives/signet-exhibition) in the exhibition, and the [Security Model](#deep-dives/security-model).
