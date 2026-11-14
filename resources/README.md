# Embedded resources

Data files Ignis loads at startup, copied unchanged from Dragonfly and its
dependencies.

| File | Source | SHA-256 |
| --- | --- | --- |
| `block_states.nbt` | Dragonfly v0.11.6 `server/world/block_states.nbt` (Minecraft 1.26.60, protocol 2225) | `88b8c903ac75d46247bed5ff785c0c050068d28440190f7412d697b045d2d51f` |
| `vanilla_items.nbt` | Dragonfly v0.11.6 `server/world/vanilla_items.nbt` (Minecraft 1.26.60, protocol 2225) | `b3a2e88d38525e494a1a3658cec2f02bd03c74975ed67cedad518beceeadef8f` |

| `legacy_states.nbt` | Dragonfly v0.11.6 `server/world/chunk/legacy_states.nbt` | `a07a8a60d868c3334f7a57b2ff020a28a7a76397f40fd42ff8e5e44f08cb87e3` |
| `worldupgrader/blockupgrader/schemas/*.json` | `github.com/df-mc/worldupgrader` v1.0.22 `blockupgrader/schemas/` (36 files) | `39c7d2b9da3804841d082c7352f9314a41a16aeb204e78bb513f3231d24c3337` (of the files concatenated in name order) |

`block_states.nbt` is a sequence of network-little-endian NBT compounds
`{name, states, version}`, one per block state, in the order Dragonfly
registers them. `ignis.world.block_registry` loads it.

`vanilla_items.nbt` is one network-little-endian compound mapping each item
name to `{runtime_id, component_based, version, data?}`: the item table
StartGame carries and the item runtime IDs. `ignis.world.item` loads it.

`legacy_states.nbt` maps pre-1.13 `{name, meta}` blocks to flattened states
(network-little-endian `{legacy, updated}` compounds); the schemas upgrade
stored block states to the current version. Both are loaded by
`ignis.world.chunk.conversion.Upgrades` for the world provider.

When Dragonfly is bumped, copy the new files, update this table, and
regenerate the test vectors with `interop/world` and `interop/items` (see
their `main.go`).
