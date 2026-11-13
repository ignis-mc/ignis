# Embedded resources

Data files Ignis loads at startup, copied unchanged from Dragonfly.

| File | Source | SHA-256 |
| --- | --- | --- |
| `block_states.nbt` | Dragonfly v0.11.6 `server/world/block_states.nbt` (Minecraft 1.26.60, protocol 2225) | `88b8c903ac75d46247bed5ff785c0c050068d28440190f7412d697b045d2d51f` |

`block_states.nbt` is a sequence of network-little-endian NBT compounds
`{name, states, version}`, one per block state, in the order Dragonfly
registers them. `ignis.world.block_registry` loads it.

When Dragonfly is bumped, copy the new files, update this table, and
regenerate the test vectors with `interop/world` (see its `main.go`).
