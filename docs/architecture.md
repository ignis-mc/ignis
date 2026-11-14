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
| `world.World` + `World.Exec(func(*Tx))` | `world.World[T]`; transactions are direct calls during the loop, `Tx` is an alias of `World` |
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
`block_set.mojo`). `ignis.block` defines all 225 Dragonfly block types
(state, encoding, hash, registration, light and break data); their
behaviour (`world.Tx`, items, entities) is listed per module after
`TODO(world-runtime):`.

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
  `test/ignis/world/test_block_set.mojo`). A behaviour the world calls
  also gets a method in the `BlockTypes` trait, which `BlockSet`
  implements. Registry flags that Go derives
  from interfaces (`LightEmitter`, `LightDiffuser`, `RandomTicker`, later
  `NBTer`, `Liquid`, `LiquidDisplacer`) are computed the same way in
  `register_block[T]`.
- **Go's embedded helper structs** (`solid`, `transparent`, `empty`,
  `replaceable`, ...) cannot be embedded in Mojo: write the methods they
  supply on each block and say which helper they come from (Air's
  `light_diffusion_level` is Go's `transparent`).
- Mojo allows circular imports between packages and modules (the world
  and the block, entity and handler traits refer to each other). The world
  is generic over its block set (`WorldTypes.Blocks`, any `BlockTypes`),
  so tests and custom servers can add block types; `BlockTypes` lists the
  dispatchers a world needs (scheduled, neighbour and random ticks, block
  items).

Porting a block type, mechanically:

1. `server/block/x.go` → `src/ignis/block/x.mojo`: the struct with Go's
   fields in Go's order (`snake_case`), `BASE_HASH = HASH_X`, `hash` copied
   from `hash.go`, `from_hash` unpacking the same bits, `encode_block`,
   `all_states` from the `RegisterBlock` calls (or Go's `allX()`), and each
   ported method. Methods that need unported packages wait for them; the
   module docstring lists them after `TODO(world-runtime):` with their Go
   names.
2. The constructor takes every field as a keyword argument defaulting to
   Go's zero value, so `Log(wood=WoodType.SPRUCE)` reads like
   `Log{Wood: SpruceWood()}`.
3. Conform to the behaviour traits it implements in Go (`Breakable`,
   `LightEmitter`, `LightDiffuser`, ...). Go's embedded `transparent`
   becomes `light_diffusion_level() -> 0`.
4. Add the type to `VanillaBlocks` in `block/register.mojo` (sorted by
   name).
5. Test: `test/ignis/block/test_register.mojo` checks every runtime ID
   against `test/data/world/blocks.txt` from `interop/world` (type, state
   hash, encoded state, light, break info); add unit tests for anything
   non-trivial.

Conventions shared by the block port:

- **Enumerations** (Go `WoodType{wood}` with `OakWood()` constructors, or
  `cube.Direction` integer constants) are small structs with `comptime`
  members: `WoodType.OAK`, `Colour.LIGHT_BLUE`, `Direction.NORTH`,
  `Face.UP`, `Axis.Y`. `uint8()` (or `Int(x)` for the `cube` integers) and
  `T(v)` convert to and from the hashed value, `write_to` is Go's
  `String()`, and `wood_types()` etc. list every value as Go's
  `WoodTypes()` does.
- **`BreakInfo`** is data: `hardness`, `blast_resistance`, `xp_drops` and
  two `ToolFilter`s (tool types plus a minimum harvest level) for Go's
  `Harvestable` and `Effective` closures. Drops, break handlers and break
  durations need items and `world.Tx` and come with them.
- **Data that Go keeps outside the state** (NBT fields such as a note
  block's pitch or a chest's custom name) are fields too, compared by
  `__eq__` but not hashed, so `from_hash` gives their zero values as Go's
  registry does. Fields whose types are not ported yet (inventories,
  `item.Stack`, entity handles) are in the module's TODO list.
- **Name clashes**: Go's `block.String` is `StringBlock`, so that importing
  it does not shadow the built-in `String`.
- **Dragonfly bugs fixed while keeping the wire states**: plain and red
  nether brick slabs and stairs are no longer swapped
  (`slab_type.mojo`, `stairs_type.mojo`; `test_register` maps Go's state
  hashes for those values), and `Attachment.rotate_right` rotates right.
- **Blocks that hold a block** (Go `Slab{Block: Planks{}}`) store it as an
  `AnyBlock`: the type's `BASE_HASH` and the block's `hash()`, which is what
  Go's `hashBlock` packs into the outer hash. `get[T]()` is Go's type
  assertion.

Block models (`ignis.block.model`, Go `server/block/model`) follow the same
shape:

- Each Go model type is a struct conforming to `world.BlockModel`
  (`bbox[S: BlockSource](pos, src)`, `face_solid[S](pos, face, src)`) with
  a unique `MODEL_ID`. A block type conforms to `world.ModelledBlock`:
  `comptime ModelType` names its model type and `model()` builds it (Go
  `Model()`).
- `world.BlockSource` (Go `world.BlockSource`) returns the runtime ID at a
  position and maps runtime IDs to the registry's `kind` and state hash, so
  that models can look at their neighbours; the world and transactions
  implement it.
- For a block of unknown type (an `AnyBlock`, e.g. from
  `register.block_at(src, pos)`), `register.block_model_bbox`,
  `block_model_face_solid` and `block_model_as[M]` (Go's type assertion
  `b.Model().(model.Fence)`) dispatch over `VanillaBlocks`; states without
  a type have Go's `unknownModel`, a solid full cube.

`BasicBlockRegistry.finalize` checks what Go's `Finalize` checks: every
registered state is unique, no two blocks share a block hash, no network
hash collides, and air exists.

### Items

Implemented in `ignis.world.item` (Go `world/item.go`) and `ignis.item`:
all 132 Dragonfly item types and the 219 block types registered as items
(1434 registered items), the creative inventory (`ignis.item.creative`)
and the recipes (`ignis.item.recipe`). Behaviour that needs players, the
world or entities (`Use`, `UseOnBlock`, `Release`, applying `Consume`, ...)
is listed per module after `TODO(player):` or `TODO(world-runtime):`.

- **An item type is a struct conforming to `world.Item`**: `BASE_HASH`,
  `encode_item() -> EncodedItem` (Go `EncodeItem`'s name and meta),
  `hash()`, `from_hash()` and `all_items()` (the `RegisterItem` calls).
  Dragonfly has no item hashes, so an item's `BASE_HASH` is
  `item_hash("GoTypeName")` (FNV-1a 64, computed at compile time). A block
  that is an item conforms to both `Block` and `Item` and keeps its block
  `BASE_HASH`; the two traits share `hash` and `from_hash`. Variants are
  packed into `hash` (tier index, potion ID, colour, ...); NBT-only fields
  (trims, leather colour, book pages, firework explosions) are fields
  compared by `__eq__` but not hashed.
- **`world.ItemHasher`**: a block whose item identity holds data outside
  its state (a banner's or bed's colour, the note block Go registers with
  pitch 24) gives `AnyItem` its `item_hash` instead of the state hash;
  `ItemSet.state_hash` maps it back for the block registry.
- **An item of unknown type is an `AnyItem`** (`kind`, `hash`, `block`).
  `it.get[Stick]()` replaces Go's `it.(Stick)`.
- **Go's optional item interfaces are traits** (`MaxCounter`, `Durable`,
  `Repairable`, `Tool`, `Armour` and the slot traits, `Consumable`,
  `Smeltable`, `Fuel`, `Enchantable`, `Compostable`, `OffHand`, `Weapon`,
  `Cooldown`, `BeaconPayment`, `ArmourTrimMaterial`, `world.NBTer`), and
  `item.ItemSet[*Ts]` has one dispatcher per trait taking `(kind, hash)`
  (`fuel_info`, `smelt_info`, `item_nbt`, ...), as `BlockSet` does for
  blocks. Go's `Consume(tx, c)` acts on the consumer; here
  `Consumable.consume_info()` describes it as data (food, saturation,
  effects with Go's chance, removed effects, the stack left over).
- **`ItemRegistry`** replaces Go's item globals: it loads
  `resources/vanilla_items.nbt` (runtime IDs exactly as Dragonfly assigns
  them, and the StartGame item table via `item_entries()`), and items are
  registered into it (`ignis.item.register.vanilla_item_registry`, over
  `VanillaItems` and `VanillaBlockItems`).
- **`item.Stack`** holds an `AnyItem`, an `ItemInfo` (max count,
  durability, ...) computed from the type's traits when the stack is
  created, and, for `NBTer` items, the item's `EncodeNBT` as a `Tree`
  (Go's stack holds the item value; `item_as[T]` decodes it back). Stacks
  start with network ID 0; the layer that sends them assigns IDs (Go uses a
  global counter).
- The network form of stacks is `ignis.session.item` (`stack_from_item`,
  `stack_to_item`), byte-exact against Dragonfly. `ignis.session.creative`
  and `ignis.session.recipes` build `CreativeContent` and `CraftingData`;
  both match Dragonfly byte for byte (with NBT keys sorted, since Go's map
  order is random, and recipe IDs passed in, since Go's are random UUIDs).
- Tests: `test/ignis/item/test_register.mojo` rebuilds every line of
  `test/data/items/defs.txt` from `interop/items` (type, name, meta, block
  state, max count, durability, tool, armour, food, fuel, smelting,
  enchantability, repair items, compost chance, weapon data).

### The world and transactions

`ignis.world.World[T: WorldTypes]` is Go's `World` with the methods of
`Tx`, `ticker`, `Loader` and `weather`. `WorldTypes` names, at compile
time, everything Go configures with interface values:

```mojo
struct ServerWorld(WorldTypes):
    comptime Generator = Flat          # world.Generator
    comptime Provider = MemoryProvider # world.Provider
    comptime Viewer = SessionViewer    # what loaders show the world to
    comptime Handler = ServerHandler   # world.Handler
    comptime Blocks = VanillaBlocks    # world.BlockTypes (BlockSet)
    comptime Entities = VanillaEntities  # world.EntityTypes (EntitySet)
```

- **Transactions**: `Tx` is an alias of `World`. Go's
  `w.Exec(func(tx *Tx) { tx.SetBlock(...) })` is `w.set_block(...)`.
  Callbacks that Go passes a `*Tx` (block ticks, entity ticks, handlers)
  receive `mut tx: World[T]`, generic over `T`.
- **Ticking**: the loop calls `w.tick(now_ms)` when `w.next_deadline_ms()`
  passes; it runs every 50 ms tick that is due (`advance_tick`, Go
  `ticker.tick`) and the periodic unload and save. Worlds without viewers
  do not tick unless `Config.synchronous`.
- **Chunks** load synchronously on the loop: from the provider, else from
  the generator. `Loader` loads are bounded by the `n` passed to
  `w.load(id, n)`, which is how a session limits generation per tick.
- **Block models** read blocks through a `BlockSource`. `World` cannot
  conform itself (`World.block` loads chunks and needs `mut self`, while
  `BlockSource.block` takes `self`), so `tx.source()` returns a
  `WorldSource` view that holds a pointer to the world and loads chunks
  like Go's `*Tx`: `model.face_solid(pos, Face.UP, tx.source())`.
  `BlockTypes.face_solid` dispatches models over the world's block set.
- **Callbacks into the world's own parts**: the world takes its handler
  (and a ticking entity) out of itself while calling it, so the callee can
  use the world mutably. A handler cannot reach itself through `tx`, and an
  entity cannot look itself up while it ticks.
- **Durations** are milliseconds (Go `time.Duration`); `delay_ms // 50`
  ticks, as Go divides by `time.Second / 20`.
- **Randomness**: `ignis.internal.rand` is Go's `math/rand/v2` PCG and
  `Rand`, so seeded worlds draw Dragonfly's numbers. `tx.rand()` is the
  world's generator (Go passes it to random and scheduled ticks);
  `tx.global_rand()` stands in for Go's global `math/rand` source, which
  Dragonfly's blocks use for drops and the like, so those draws leave the
  world's generator in step with Dragonfly's.
- **Entities tick in a stable order** (Go ranges over a map, in random
  order), so for example a stack of falling blocks always lands cleanly.
- **Errors** Go logs (provider failures) go to `World.last_error`.

### Block behaviour

The world-driven behaviour of blocks (Go's `RandomTick`, `ScheduledTick`,
`NeighbourUpdateTick`, liquids) is ported in the block modules; the world
dispatches it through `BlockTypes`.

- **Liquids** (`block/liquid.mojo`, `water.mojo`, `lava.mojo`): a liquid
  conforms to `world.Liquid`; `tick_liquid[L]` is Go's `tickLiquid` for any
  typed liquid. The blocks it meets are runtime IDs, whose `Liquid`,
  `LiquidDisplacer` (waterlogging) and `LiquidRemovable` methods go
  through the block set. `tx.liquid(pos)` and `tx.set_liquid(pos, l)` are
  Go's `Tx.Liquid`/`SetLiquid` over layers 0 and 1, and `set_block` keeps a
  displaced liquid on layer 1.
- **Go interfaces a block's neighbours are asked about** become traits
  with a `BlockSet` dispatcher taking `(kind, hash)`: `Soil`
  (`supports_vegetation`), `Crop`, `Flammable`, `Oxidisable`,
  `Solidifiable`, `LightDiffuser`, `Replaceable`, `Liquid*`. Helpers
  such as `face_solid_at(tx, pos, face)` read a neighbour's model.
- **Item drops**: `tx.drop_item(pos, stack)` (Go's `dropItem`) queues the
  stack; the world cannot build item entities (their NBT needs the item
  registry), so the server spawns the queued drops after each world tick
  (`take_item_drops`). `break_block`/`break_block_no_drops` are Go's.
- **Entities spawned by blocks**: `EntityTypes.try_wrap(E())` wraps an
  entity type or gives None if the world's set lacks it; falling blocks
  (`entity/falling_block.mojo`) spawn that way.
- **Light**: blocks read `tx.light`, `sky_light` and `block_light` (see
  "Light" below). Liquids set with `set_liquid` relight like blocks set
  with `set_block`.
- **Handler events** for liquids, leaves, fire and crops are on
  `world.Handler` (blocks as `AnyBlock`); blocks call them through
  `tx.handle_*`. Sounds and particles go to viewers (`tx.play_sound`,
  `tx.add_particle`, `Viewer.view_sound`/`view_particle`); sessions do not
  turn them into packets yet.
- **Vectors**: `interop/behaviour` runs Dragonfly's own ticks on small
  seeded worlds (liquids, light, neighbour updates and falling blocks, one-
  chunk random-tick worlds) and the tests under `test/ignis/block/` and
  `test/ignis/world/chunk/test_light_features.mojo` match them block for
  block; see
  its README for what makes a world deterministic in Go.

### Viewers and loaders

- **`world.Viewer`** is a trait whose methods all have empty default bodies
  (Go's `NopViewer` embedding). Blocks are runtime IDs; entity methods are
  generic over the entity set (`view_entity[E](e: EntityHandle[E])`).
- **The world owns its loaders and their viewers.** Go's `Loader` is held
  by the session and points at the world; here `w.add_loader(radius,
  viewer^) -> LoaderID` moves the viewer into the world, `move_loader`,
  `load`, `change_loader_radius` replace the loader's methods, and
  `close_loader(id)` gives the viewer back (Go `ChangeWorld` is
  close-then-add). A session reaches its viewer with `w.viewer(id)`, or
  shares state with it (a packet queue) through an `ArcPointer`.
- `test/support/world_runtime.mojo` has a `RecordingViewer` that records
  every call, which is how the world tests check notifications.

### Entities

Implemented in `ignis.world.entity` with `ignis.entity.text.Text` as the
worked example.

- **An entity type is a struct conforming to `world.EntityType`**: its
  `IDENTIFIER` (Go `EncodeEntity`), `bbox`, `encode_nbt` and `decode_nbt`.
  The struct is also the entity's behaviour state (Go `EntityData.Data`);
  Go's separate `EntityType` value and opened `Entity` collapse into it.
- **An entity is an `EntityHandle[E]`**: its UUID, the shared `EntityData`
  (position, velocity, rotation, name, fire, age) and `state: E.State`,
  a `Variant` over the types of the entity set `E = EntitySet[*Ts]`. The
  world owns the handles of its entities and addresses them by UUID;
  `remove_entity` gives the handle back so it can join another world.
- **Behaviours** some types have become traits refining `EntityType`
  (`TickerEntity`, `NetworkEncodedEntity`), dispatched by `EntitySet` with
  `comptime if conforms_to(...)`. A ticking entity is taken out of the
  world during `tick(mut self, id, mut data, mut tx, current)` and returns
  an optional `EntityMovement` that the world shows to viewers (Go
  `Movement.Send`). An entity that removes itself while ticking is removed
  when its tick ends.
- `EntitySet.wrap(T())` builds a state; `e.state[T]` / `e.state.isa[T]()`
  replace Go's type assertions where the set is concrete.
- Adding a type is: write the struct, add it to the `EntitySet` the server
  uses (`ignis.entity.register.VanillaEntities`). Player types will join it
  with the player package; keep large state behind an `OwnedPointer`
  (moved structs must stay small).

### Other interfaces

- `world.Generator`, `world.Provider`, `world.Handler`: traits named in
  `WorldTypes`; biomes are stored by ID (`encode_biome`).
- `world.Dimension`: a small value type with `OVERWORLD`, `NETHER` and `END`
  constants (the vanilla set is closed; custom dimensions are values too).

### The server and sessions

Implemented in `ignis.server` (Go `server.go`, `conf.go`) and
`ignis.session` (Go `session/`), run by `cmd/ignis/main.mojo`.

- **`server.Server.step`** is the loop above: poll the listener, pending
  connections and sessions; accept and `start_game` with Dragonfly's
  default `GameData`; turn spawned connections into sessions; handle each
  session's packets; tick the world on its deadline and the sessions at
  20 TPS (`send_chunks`); flush every session.
- **`session.Session[C: session.Conn]`** owns its connection (`NetConn`
  over the protocol `Conn`, `FakeConn` in tests) and its `player.Player`.
  `handle_packet` returns a `HandleResult` (moved, metadata changed, chat
  line) and the server calls the other sessions' `view_*` methods, since a
  session cannot reach the others.
- **Chunks go through the world's loaders.** The server adds a loader per
  session with a `SessionViewer` over the session's `PacketQueue`
  (`ArcPointer`); the session drains the queue into its connection in
  order with its own packets.
- **StartGame must list the data-driven blocks**
  (`resources/data_driven_blocks.nbt`): they are part of the client's
  block palette, and without them every sequential runtime ID after them
  is shifted on the client.
- Players are not world entities yet: until the player package adds them
  to the entity set, the server shows every player to every other one.
- `config.toml` keeps Dragonfly's tables and keys (`[Network] Address`,
  `[Server] Name`, ...), read by a TOML subset parser
  (`ignis.internal.toml`).
- **Worlds and players on disk**: `[World] SaveData`/`Folder` open the
  world with `world.mcdb` (`server.provider.WorldProvider`, which is either
  the `mcdb.DB` or nothing), `[Players] SaveData`/`Folder` open
  `player.playerdb` (Dragonfly's JSON in LevelDB). The server saves the
  world, `level.dat` and the online players every `save_interval_ms`
  (the world's own auto save is off), a player's data when they leave, and
  everything in `Server.close`.
- **Shutdown**: SIGINT and SIGTERM arrive through a `signalfd`
  (`internal.signal`) the loop polls; `run` then calls `close`. The Mojo
  runtime starts worker threads before `main`, and a process-directed
  signal goes to any thread that does not block it, so `main` calls
  `termination_signals()` first: it blocks the signals and re-executes
  `/proc/self/exe` once, and the runtime's threads inherit the mask. Run
  the server as a built binary (`pixi run serve` builds it), not with
  `mojo run`.
- **Commands**: `server.command.CommandSource` is the server's one
  `cmd.Source` (a player or the console) and `ServerTx` its `Tx`, a pointer
  to the server valid while a command runs (Go's `*world.Tx`).
  `CommandRequest` makes `handle_packet` return the line, and the server
  runs it with `execute_command` (Go `Player.ExecuteCommand`) and answers
  with `CommandOutput`. Sessions get `AvailableCommands` on spawn and the
  server runs Go's `resendEnums` every second and `resendCommands` every
  five. Lines on stdin run as the console (`internal.stdin.LineReader`).
  `server.builtin` registers `/gamemode`, `/tp`, `/time`, `/list` and
  `/say`.

### Inventories and interaction

- **Inventories** (`item.inventory`, Go `item/inventory`) collect changed
  slots instead of calling a `SlotFunc`; the session sends the changes made
  outside item stack requests. Stacks get network IDs from a `StackIDs`
  source shared by a session's inventories; `Stack.grow`/`add_stack` clear
  the ID as Go draws a new one. The session owns the player's inventories
  (`session.inventory.Inventories`) so copying a `Player` stays cheap.
- **Item stack requests** (`session.handler_item_stack_request`) run on
  `Inventories` alone and return the response, so they are tested without
  a connection.
- **Breaking and placing** (`server.interact`) are server functions for
  the player of a session, as Go's player methods reach the world through
  their transaction. Like Dragonfly, the server computes break times for
  the crack animation and trusts the client's finish.
- **Block behaviour for interaction** goes through `BlockTypes`
  dispatchers: `model_bbox`, `break_info`, `replaceable_by` (Go
  `Replaceable`), `drops` (`Dropper`, Go `BreakInfo.Drops`; others drop
  themselves) and `use_on_block` (`UsableOnBlock`, Go `item.UsableOnBlock`
  on blocks, returning the `Placement`s). Held tools go through
  `ItemSet.tool` and `ItemSet.durability_info`.
- **Item entities** (`entity.item`) tick their own physics
  (`entity.movement`, Go `MovementComputer`) and keep their stack's disk
  NBT, because entity NBT callbacks get no registries. Picking up and
  merging need players and the concrete entity set, so the server does
  them each tick. A session and its world viewer share entity runtime IDs
  through their `PacketQueue`.

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
- `resources/vanilla_items.nbt` holds the item runtime IDs and the
  StartGame item table.
- Providers store `chunk.Column`s: the chunk, its entities as NBT (Go's
  `encodeNBT` fields plus the type's), and its scheduled block updates.
  `MemoryProvider` keeps them in memory; unloaded chunks come back intact.
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
- Not ported yet: block entities, redstone, and the client blob cache.

## Light

Implemented in `ignis.world.chunk` (`light.mojo`, `light_area.mojo`,
`light_type.mojo`; Go `light.go`, `light_area.go`, `light_type.go`) and
wired into `World`. Light is server-side state (the client computes its
own); crops, grass, saplings and ice read it.

- Sub-chunks hold sky and block light as `LightArray`s (Go's 2048-byte
  nibble slices; a uniform array stands for Go's shared `fullLight` and
  `noLight` until it is written).
- A `LightArea` is Go's `lightArea` over `ChunkPointer`s into chunks the
  caller owns. Loading a chunk runs `Fill` on it, then `Spread` for every
  loaded chunk whose 3x3 neighbourhood it completes, as Go's `loadChunk`
  and `addChunk` do.
- Dragonfly never relights after a load. Ignis relights around every block
  change (`chunk.light.relight`, called from `set_block_runtime_id` when the
  emitted or filtered light or the height map changes), and the result is
  what Dragonfly computes when it loads the chunks again, quirks included:
  the block at a column's height map value does not light its neighbours in
  the same chunk. Fixed: `Spread` also crosses borders in the top
  sub-chunk.
- The world API is Go's: `light(pos)` (does not load chunks),
  `sky_light(pos)` and `block_light(pos)` (load them), all 0 to 15.
- `interop/light` writes per-chunk hashes of every light array for six
  scenarios, before and after block changes; `test_light.mojo` and
  `test_world_light.mojo` reproduce them exactly.

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
