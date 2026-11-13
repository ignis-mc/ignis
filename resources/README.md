# Embedded resources

Data files Ignis loads at startup, copied unchanged from Dragonfly.

| File | Source | SHA-256 |
| --- | --- | --- |
| `block_states.nbt` | Dragonfly v0.11.6 `server/world/block_states.nbt` (Minecraft 1.26.60, protocol 2225) | `88b8c903ac75d46247bed5ff785c0c050068d28440190f7412d697b045d2d51f` |
| `vanilla_items.nbt` | Dragonfly v0.11.6 `server/world/vanilla_items.nbt` (Minecraft 1.26.60, protocol 2225) | `b3a2e88d38525e494a1a3658cec2f02bd03c74975ed67cedad518beceeadef8f` |

`block_states.nbt` is a sequence of network-little-endian NBT compounds
`{name, states, version}`, one per block state, in the order Dragonfly
registers them. `ignis.world.block_registry` loads it.

`vanilla_items.nbt` is one network-little-endian compound mapping each item
name to `{runtime_id, component_based, version, data?}`: the item table
StartGame carries and the item runtime IDs. `ignis.world.item` loads it.

When Dragonfly is bumped, copy the new files, update this table, and
regenerate the test vectors with `interop/world` and `interop/items` (see
their `main.go`).
