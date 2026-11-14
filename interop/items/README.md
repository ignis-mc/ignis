# Item test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes the
expected values that the Mojo tests under `test/ignis/world/` and
`test/ignis/item/` compare against:

- `items_sample.txt`: entries of the StartGame item table as Dragonfly's
  `server.go` decodes `vanilla_items.nbt` (runtime ID, name, component
  based, version, item data), one in 37 plus every fifth entry with data;
  `vectors.txt` holds the SHA-256 of the full listing. The program checks
  that `world.ItemRuntimeID` returns the same runtime ID for every name.
- `vectors.txt`: runtime IDs and metadata of the example items and block
  items, and the network `ItemStack` that Dragonfly's session builds for a
  few stacks (count, damage, custom name, lore, unbreakable, anvil cost).

Go decodes NBT compounds into maps, whose iteration order is random, so item
data and stack NBT are written in a canonical text form with sorted keys
(see `canonical`). Marshalled `ItemStack` bytes are only written where every
compound has at most one key.

Regenerate from the repository root:

```sh
(cd interop/items && go run . -out ../../test/data/items)
```
