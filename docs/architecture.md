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
| goleveldb / mcdb | `ignis.leveldb` (goleveldb's format, synchronous flush, compaction in bounded steps) / `ignis.world.mcdb` |

## Polymorphism

Dragonfly leans on Go interfaces with many implementations: `world.Block`
(hundreds of block types), `item.Item`, `world.Entity`, `world.Generator`,
`cmd.Runnable`. Mojo 1.2 has traits but no trait objects, so a value whose
type is only known at run time cannot be held behind a trait. Ignis uses
traits for static polymorphism and a compact runtime handle plus a
compile-time type list for dynamic dispatch.

### Blocks

Implemented in `ignis.world` (`block.mojo`, `block_registry.mojo`,
`block_set.mojo`) with air, stone, grass, dirt and bedrock in `ignis.block`
as the worked example.

- **A block type is a struct conforming to `world.Block`**:
  `BASE_HASH` (the type's `hash*` constant from Go's generated
  `block/hash.go`, all of them already in `ignis/block/hash.mojo`),
  `encode_block() -> BlockState` (Go `EncodeBlock`), `hash() -> UInt64`
  (the second value of Go's `Hash()`), `from_hash(hash) -> Self` (its
  inverse) and `all_states() -> List[Self]` (the values Go's
  `block/register.go` registers for the type).
- **A block of unknown type is its runtime ID (`UInt32`).** Chunks, the
  world and packets carry runtime IDs. Where Go returns or stores a
  `world.Block` without knowing its type, Ignis uses the runtime ID; a list
  of mixed blocks (`[]world.Block`) is a `List[UInt32]`.
- **The registry maps runtime IDs to types.** `BasicBlockRegistry` keeps,
  per runtime ID, the state, the `BASE_HASH` of the registered type (`kind`)
  and its state hash, plus Dragonfly's packed light/flag info.
  - Typed value to runtime ID: `br.block_runtime_id(Dirt(coarse=True))`.
  - Go's `b, ok := x.(Dirt)`: `br.block[Dirt](rid)` returns
    `Optional[Dirt]`; `br.is_block[Dirt](rid)` is the bare check.
  - States without a Mojo type yet behave like Go's `unknownBlock`
    (`kind == UNKNOWN_KIND`): they still encode, decode and send.
- **Behaviour is dispatched through `world.BlockSet[*Ts]`**, a struct over
  the list of every block type (`ignis.block.register.VanillaBlocks`). A Go
  interface that only some blocks implement (`RandomTicker`,
  `ScheduledTicker`, `NeighbourUpdateTicker`, `Activatable`, ...) becomes a
  trait refining `Block`, and `BlockSet` gets one static method per such
  trait that loops over `Ts` at compile time, keeps the types for which
  `conforms_to(T, Trait)` holds, compares `kind` with `T.BASE_HASH` and
  calls `T.from_hash(state_hash)` (see the example in `block_set.mojo` and
  `test/ignis/world/test_block_set.mojo`). Registry flags that Go derives
  from interfaces (`LightEmitter`, `LightDiffuser`, later `NBTer`,
  `RandomTicker`, `Liquid`, `LiquidDisplacer`) are computed the same way in
  `register_block[T]`.
- **Go's embedded helper structs** (`solid`, `transparent`, `empty`,
  `replaceable`, ...) cannot be embedded in Mojo: write the methods they
  supply on each block and say which helper they come from (Air's
  `light_diffusion_level` is Go's `transparent`).
- Mojo allows circular imports between packages, so `ignis.world` code may
  import `ignis.block.register.VanillaBlocks` for dispatch even though
  `ignis.block` imports `ignis.world`. If the world later needs custom
  blocks, make it generic over the block set instead.

Porting a block type, mechanically:

1. `server/block/x.go` → `src/ignis/block/x.mojo`: the struct with Go's
   fields in Go's order (`snake_case`), `BASE_HASH = HASH_X`, `hash` copied
   from `hash.go`, `from_hash` unpacking the same bits, `encode_block`,
   `all_states` from the `RegisterBlock` calls (or Go's `allX()`), and each
   ported method. Methods that need unported packages wait for them.
2. Conform to the behaviour traits it implements in Go.
3. Add the type to `VanillaBlocks` in `block/register.mojo`.
4. Test: `from_hash(b.hash()) == b` for `all_states()`, `encode_block`, and
   the runtime IDs and `block_hash` against values from `interop/world`.

`BasicBlockRegistry.finalize` checks what Go's `Finalize` checks: every
registered state is unique, no two blocks share a block hash, no network
hash collides, and air exists.

### Items

Not ported yet; the plan follows blocks. Each item type conforms to an
`item.Item` trait (`BASE_HASH`, `encode_item() -> (name, meta)`, `hash`,
`from_hash`); an item of unknown type is its `(kind, state hash)` pair, or
the runtime ID for blocks used as items; an `ItemSet[*Ts]` dispatches
behaviour as `BlockSet` does. Item IDs come from `vanilla_items.nbt`.

### Other interfaces

- `world.Generator`, `world.Biome`: traits; a world is generic over its
  generator, and biomes are stored by ID (`encode_biome`).
- `world.Dimension`: a small value type with `OVERWORLD`, `NETHER` and `END`
  constants (the vanilla set is closed; custom dimensions are values too).

## World data

- `resources/block_states.nbt` (with the other Dragonfly resources as they
  are needed) is loaded at startup; `resources/README.md` records the
  source version and checksum.
- Chunks do not hold the registry; the few chunk methods that need it take
  it as an argument.
- Chunks are sent the way Dragonfly sends them: sequential runtime IDs
  (`StartGame` leaves `UseBlockNetworkIDHashes` off), `LevelChunk` with
  biomes only and sub-chunk requests answered with network-encoded
  sub-chunks (`ignis.session.chunk`).
- Worlds on disk use the vanilla format through `ignis.world.mcdb` over
  `ignis.leveldb`. Disk chunk encoding is `chunk.disk_encode`/`disk_decode`;
  stored block states are upgraded with `df-mc/worldupgrader`'s schemas
  and `legacy_states.nbt` (`chunk.conversion.Upgrades`, loaded once and
  owned by the provider; Ignis has no globals). The provider shares the
  world's registry as `ArcPointer[BasicBlockRegistry]`.
- LevelDB work is synchronous: a write appends to the journal and the
  memtable; a full memtable (4 MiB) is written as a level-0 table in the
  writing call, followed by at most two compaction steps. Long pauses can
  be avoided by calling `DB.compact_once()` from idle time.
- Not ported yet: the light engine (server-side only; the client computes
  its own light) and the client blob cache.
