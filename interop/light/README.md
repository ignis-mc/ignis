# Light test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes
`test/data/light/vectors.txt`, which `test/ignis/world/chunk/test_light.mojo`
and `test/ignis/world/test_world_light.mojo` compare against:

- Six scenarios (`flat`, `overhang`, `emitters`, `diffusion`, `border`,
  `terrain`), each a square of chunks (3x3, 4x4 or 5x5) built from `fill`,
  `sphere` and `columns` lines (positions, layer, runtime ID).
- The chunks are lit as `World.loadChunk` and `World.addChunk` do when they
  load in the listed order (`load` lines): `Fill` per chunk, then `Spread`
  for every chunk whose 3x3 neighbourhood is complete. The program checks
  the result against `Tx.Light`, `Tx.SkyLight` and `Tx.BlockLight` of a
  real Dragonfly world that loads the same chunks in the same order.
- `light <step> <cx> <cz> <sky> <block>`: the FNV-1a 64 hash of the chunk's
  sky light arrays and of its block light arrays (2048 bytes per
  sub-chunk, lowest first, in Dragonfly's nibble layout). `-subs` writes a
  hash per sub-chunk instead, to find a mismatch.
- `probe <step> <x> <y> <z> <light> <sky> <block>`: the levels at a few
  positions.
- `step <n>` lines start block changes. Dragonfly does not relight when a
  block changes, so the expected light after a step is what Dragonfly
  computes when it loads the changed chunks afresh in the same order; Ignis
  must reach it by relighting incrementally. The program checks that every
  result is a fixed point of Dragonfly's propagation (with Dragonfly's
  quirk that the block at a column's height map value does not light its
  neighbours in the same chunk), so it is the only answer an incremental
  engine can give.

Regenerate from the repository root:

```sh
(cd interop/light && go run . -out ../../test/data/light)
```

`go run . -bench` times Dragonfly's `Fill` and `Spread` for comparison with
`cmd/lightbench`.
