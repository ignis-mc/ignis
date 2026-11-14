# Block behaviour test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`), builds small
synchronous worlds seeded with `rand.NewPCG(1, 2)` (Ignis seeds its tests
the same way) on the flat test world (grass at y=-62 on dirt on bedrock),
runs Dragonfly's own ticks and records what happened:

- `liquids.txt` (`liquids.go`): water and lava flowing, hardening and
  waterlogging. Each line is `scenario tick x,y,z layer rid state` for a
  block that differs from the flat world, then `scenario tick entities n`.
  Checked by `test/ignis/block/test_liquid.mojo`.
- `light.txt` (`light.go`, `features.go`): the sky and block light of a
  world whose features are placed while generating, after loading chunks
  -2..2. Checked by `test/ignis/world/chunk/test_light.mojo`.

Regenerate from the repository root:

    (cd interop/behaviour && go run . -out ../../test/data/behaviour)
