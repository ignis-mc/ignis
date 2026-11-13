# World test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes the
expected bytes that the Mojo tests under `test/ignis/world/` compare against:

- `block_states_sample.txt`: every 97th runtime ID with its network block
  hash, name and properties; `vectors.txt` holds the SHA-256 of the full
  listing.
- `blocks.txt`: every runtime ID Dragonfly registers a block for, with the
  Go type, the two `Hash()` values, light emission and filtering, the
  registry flags (NBT, random tick, liquid, liquid displacing) and the
  `BreakInfo` data (hardness and blast resistance as IEEE bits, the tools
  that harvest the block and mine it faster as bit masks over the tool list
  in `tools()`, the XP range). `test/ignis/block/test_register.mojo` checks
  every Ignis block type against it.
- `cube.txt`: `block/cube` and `cube/trace` operations (boxes, rotations,
  orientations, positions, Go's `math.Sin`/`Cos`, ray traversal and
  intercepts) as `op<TAB>args<TAB>result`; `test_cube_vectors.mojo` parses
  the arguments, recomputes and compares.
- `models.txt`: for every registered state, the model's solid faces and its
  boxes with air, stone, the same block and a mix of connecting blocks
  around it; bamboo at several positions; and rays through blocks
  (`test/ignis/block/model/test_models.mojo`).
- `vectors.txt`: runtime IDs and block hashes of the implemented blocks,
  network-encoded sub-chunks and biomes, height maps, and the `LevelChunk` and
  `SubChunk` packets Dragonfly's session sends for a few fixed chunks.

Regenerate from the repository root:

```sh
(cd interop/world && go run . -out ../../test/data/world)
```
