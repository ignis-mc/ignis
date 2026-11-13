# World test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes the
expected bytes that the Mojo tests under `test/ignis/world/` compare against:

- `block_states_sample.txt`: every 97th runtime ID with its network block
  hash, name and properties; `vectors.txt` holds the SHA-256 of the full
  listing.
- `vectors.txt`: runtime IDs and block hashes of the implemented blocks,
  network-encoded sub-chunks and biomes, height maps, and the `LevelChunk` and
  `SubChunk` packets Dragonfly's session sends for a few fixed chunks.

Regenerate from the repository root:

```sh
(cd interop/world && go run . -out ../../test/data/world)
```
