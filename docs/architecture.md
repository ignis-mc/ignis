# Architecture

Ignis is a port of Dragonfly v0.11.6 to Mojo 1.2. This document records the
decisions that every package follows, so that parallel ports fit together.

## Process model

One thread runs one event loop. There are no goroutines, channels or mutexes
to port; Dragonfly's concurrency becomes ordering within a tick.

```text
loop:
    wait for readable descriptors or the next deadline (tick, timers)
    nethernet: signaling, ICE/DTLS/SCTP, accept new connections
    sessions: read packets, run handlers against the world
    world: run every tick that is due (20 TPS)
    sessions: write each session's queued packets as one batch
```

- **Deadlines** are absolute monotonic milliseconds (`nethernet.os.time`),
  as in nethernet and protocol.
- **Blocking work** (world loading, HTTP) is either done before the loop
  starts or broken into bounded steps driven by the loop.
- **Many players** are served by the same loop. If one process stops being
  enough, the plan is several processes (one per world), not threads.

## Mapping from Dragonfly

| Dragonfly | Ignis |
| --- | --- |
| `server.Server` with its goroutines | `server.Server` owning listeners, sessions and worlds, driven by the loop |
| `world.World` + `World.Exec(func(*Tx))` | `world.World`; transactions are direct calls during the loop |
| `session.Session` (one goroutine per player) | `session.Session` stepped by the loop |
| `minecraft.Listener` (gophertunnel) | the server-side `Listener` in the `protocol` submodule |
| goleveldb / mcdb | to be decided; worlds start as generated/in-memory |

## Polymorphism

Dragonfly leans on Go interfaces with many implementations: `world.Block`
(hundreds of block types), `item.Item`, `world.Entity`, `world.Generator`,
`cmd.Runnable`. Mojo 1.2 has traits but no trait objects. The core packages
settle one shape for each before the bulk of blocks and items are ported:

- **Blocks** are identified at runtime by their block state (name +
  properties → runtime ID, via `resources/block_states.nbt`). Behaviour is
  dispatched from the runtime ID to the Mojo type that implements it.
- **Items** follow the same approach with item IDs from `vanilla_items.nbt`.

The exact representation is decided in the `world` core port and recorded
here when it lands.
