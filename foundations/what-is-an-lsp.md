# What Is an LSP?

> **TLDR**: A Lightning Service Provider (LSP) is a single node that serves many users — providing channels, routing payments, and managing liquidity. In SuperScalar, one LSP coordinates an entire factory. All users in that factory share the same LSP. The LSP role can be filled by a company, a community node, or an individual operator.

## The Core Relationship: One LSP, Many Clients

A SuperScalar factory always has **one LSP and multiple clients**. The LSP is in every subtree of the factory, participates in every signing round, and has a channel with every client. Clients do not have channels with each other — every channel is between a client and the LSP.

```mermaid
graph TD
    LSP["One LSP Node"] -->|"channel"| A["Alice"]
    LSP -->|"channel"| B["Bob"]
    LSP -->|"channel"| C["Carol"]
    LSP -->|"channel"| D["Dave"]

    style LSP fill:#4c6ef5,color:#fff
```

The LSP role isn't restricted to corporations — anyone with a Lightning node, liquidity, and a server can operate as an LSP. But within any given factory, there is exactly one.

## Who Can Run an LSP?

Any of these could serve as the single LSP for a factory full of clients:

| Operator | Example | Serves |
|----------|---------|--------|
| **A company** | Phoenix (ACINQ), Breez | Thousands of mobile wallet users |
| **A community node** | A Bitcoin meetup group | Local community members |
| **An individual node runner** | Someone with a server and liquidity | Anyone who connects |

The protocol doesn't care who runs the LSP node — it only cares that the cryptographic guarantees hold. But in every case, the LSP is **one node serving many clients**.

## The Current Model (Without Factories)

```mermaid
graph TD
    LSP["LSP Node<br/>(always online)"]
    LSP -->|"1 UTXO each"| A["Alice's Channel"]
    LSP -->|"1 UTXO each"| B["Bob's Channel"]
    LSP -->|"1 UTXO each"| C["Carol's Channel"]
    LSP -->|"1 UTXO each"| D["Dave's Channel"]

    style LSP fill:#4c6ef5,color:#fff
```

**The bottleneck**: Each user requires their own on-chain UTXO. If a node operator wants to serve 1,000 users, that's 1,000 on-chain transactions just to get started.

## The SuperScalar Model (With Factories)

```mermaid
graph TD
    LSP["LSP Node<br/>(always online)"]
    LSP -->|"1 shared UTXO"| F["Factory<br/>(off-chain tree)"]
    F --> A["Alice's Channel"]
    F --> B["Bob's Channel"]
    F --> C["Carol's Channel"]
    F --> D["Dave's Channel"]

    style LSP fill:#4c6ef5,color:#fff
    style F fill:#fab005,color:#000
```

**The improvement**: Many users share one UTXO through a factory. The LSP node coordinates factory construction, provides initial liquidity, and manages the lifecycle — but **cannot steal or censor** because every transaction requires N-of-N multisig.

## How Users Find an LSP

Users don't run their own LSPs — they **connect to** one. For this to work, users need a way to discover LSPs and LSPs need a way to gather clients into factories:

- **LSP discovery**: An LSP advertises that it runs SuperScalar factories and has liquidity available
- **Client onboarding**: Users browse available LSPs, compare terms (fees, capacity, liveness requirements), and join one
- **Multiple LSPs competing**: If one LSP has bad terms or goes offline, users can migrate to another during factory transitions

The protocol doesn't mandate a specific discovery mechanism. It could be a directory, a decentralized bulletin board, or peer-to-peer gossip. What matters is that users have **choice** among LSPs.

## The LSP's Role in SuperScalar

### What the LSP Node Does
| Responsibility | Details |
|---------------|---------|
| **Coordinates factory construction** | Creates the funding transaction and tree structure with participating clients |
| **Provides liquidity** | Locks up Bitcoin as "liquidity stock" that clients can receive into |
| **Manages signing rounds** | Coordinates MuSig2 signing with online clients |
| **Runs the lifecycle** | Manages [[laddering]] — ~33 concurrent factories with staggered lifetimes |
| **Facilitates exits** | Helps clients move between factories or exit to on-chain |

### What the LSP Node Cannot Do
| Guarantee | Why |
|-----------|-----|
| **Cannot steal funds** | Every transaction uses N-of-N multisig — the LSP is just one signer among many |
| **Cannot censor unilaterally** | State updates require all participants in the affected subtree to sign |
| **Cannot prevent exit** | Exit transactions are pre-signed during construction; clients can always broadcast them |
| **Cannot refuse refund** | If the LSP stops cooperating, clients force-close and get their funds on-chain |

### The Economics

LSP operators earn revenue by providing **inbound liquidity** — the capacity for clients to receive payments:

1. The operator locks up Bitcoin as liquidity stock in each factory
2. Clients pay for inbound liquidity (via Lightning payments or fees)
3. The operator recovers capital when factories expire and new ones are created

This works whether the operator is a company serving thousands of users or a node runner serving a dozen friends. The scale is flexible.

> *"Once the LSP has sold some unit of inbound liquidity, it wants to not take back that liquidity."* — ZmnSCPxj

## The Trust Model

SuperScalar shifts risk to the LSP operator rather than clients:

> *"I have been refining SuperScalar to shift much of the risk to the LSP, precisely to prevent risks on clients."* — ZmnSCPxj

The worst case for a client: the LSP node goes offline permanently. In this case, clients perform a [[force-close|unilateral exit]], which puts their funds on-chain. It's inconvenient and costs fees, but **funds are never lost**.

## The Liveness Requirement

| Actor | Must Be Online |
|-------|---------------|
| **LSP node** | Always (it coordinates the factory) |
| **Client** | At least once during the 3-day dying period of each factory (~once per month) |

If a client misses the dying period, they must [[force-close]] — but their funds are safe.

## The Bigger Picture

SuperScalar isn't just a scaling optimization. ZmnSCPxj designed it with a specific mission: enabling financial self-sovereignty for people who have **nothing** to start with.

> *"The goal of SuperScalar is to be able to onboard people, possibly people who do not have an existing UTXO they can use to pay exogenous fees."* — ZmnSCPxj

Consider someone in a developing nation with a mobile phone and zero Bitcoin. Today, they can't use Lightning because they need an on-chain UTXO to open a channel. SuperScalar lets them receive their first sats through a factory-hosted channel — no on-chain transaction needed.

> *"One may consider this scheme as ways for a client to build up their Bitcoin holdings without having an onchain UTXO, but with an assurance that the service provider has no incentive to rug their funds until they have accumulated enough to own their own unique UTXO."* — ZmnSCPxj

The design even accounts for clients who have no funds at all to pay for exit fees. If an LSP misbehaves, a truly destitute client can take their pre-signed exit transactions to a **competing LSP**, who can broadcast them and earn a bounty for punishing the bad actor. You don't need money to have recourse — the cryptographic guarantees work regardless.

## The Decentralization Goal

The vision isn't one LSP serving everyone. It's **many LSPs** — big and small — competing on terms, with users free to move between them. SuperScalar makes this practical:

- **Low barrier to entry**: Anyone with a node and liquidity can coordinate a factory
- **Client migration**: Users can move from one LSP to another during factory transitions
- **No lock-in**: Pre-signed exit transactions mean you can always leave
- **Competitive market**: Multiple LSPs competing drives down fees and improves service

The more operators there are, the more resilient and decentralized the network becomes.

## Related Concepts

- [[why-superscalar-exists]] — The scaling challenge SuperScalar addresses
- [[factory-tree-topology]] — The structure the LSP node builds with its clients
- [[laddering]] — How factories rotate over time
- [[building-a-factory]] — Step-by-step factory construction
- [[security-model]] — Full analysis of trust assumptions
