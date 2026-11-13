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

## Commands

Implemented in `ignis.cmd` (Dragonfly `server/cmd`) and
`ignis.session.command` (the `AvailableCommands` and `CommandOutput`
packets); the package docstring of `ignis.cmd` has the full mapping.

- **A command overload is still a struct whose fields are its
  parameters**, conforming to `cmd.Runnable`. Go fills the fields by
  runtime reflection; Ignis generates each overload's parser at compile
  time from `std.reflection.reflect[R]` (`field_names`, `field_types`,
  `field_ref`) and dispatches on field types with `T == Int8`-style checks
  and `conforms_to(T, Enum)`. Unsupported field types and a required
  parameter after an optional one are compile errors.
- Go struct tags become `R.tag(field) -> StaticString`, a static method
  evaluated at compile time (`"name,suffix"`, `"-"`); fields starting with
  `_` are not parameters. Each execution starts from `R()`.
- **No trait objects:** `Command[S]` stores each overload as function
  pointers instantiated for its runnable type (execute, allow, describe
  parameters). `S` is the server's single source type; `run[S: Source]`
  stays generic. Concrete source features are reached with
  `comptime if S == Player: rebind[Player](src)`.
- Go's `*world.Tx` is the source's associated type `S.Tx: TargetProvider`,
  which lists the entities and players target selectors choose from. A
  `Target` is a value (UUID, name, position, player flag), not the entity.
- The registry is a `Registry[S]` value owned by the server, not a global.
- `AvailableCommands` visits commands sorted by name (Dragonfly's map order
  is random) and is byte-exact against Dragonfly for that order.
