# Block behaviour test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`), builds small
synchronous worlds seeded with `rand.NewPCG(1, 2)` (Ignis seeds its tests
the same way) on the flat test world (grass at y=-62 on dirt on bedrock),
runs Dragonfly's own ticks and records what happened:

- `liquids.txt` (`liquids.go`): water and lava flowing, hardening and
  waterlogging. Each line is `scenario tick x,y,z layer rid state` for a
  block that differs from the flat world, then `scenario tick entities n`.
  Checked by `test/ignis/block/test_liquid.mojo`.
- `neighbours.txt` (`neighbours.go`): blocks falling as entities (sand,
  gravel, concrete powder into water, a dragon egg) and blocks breaking or
  changing when a neighbour changes (torches, plants, doors, sugar cane,
  cacti, lanterns, carpets, farmland, leaves, a sponge). The entity line
  counts falling blocks, dropped items (summed: Dragonfly merges item
  entities) and other entities. Checked by
  `test/ignis/block/test_neighbour_ticks.mojo`. Anvils are left out: their
  wear when they land is drawn from Go's global random source.
- `random_ticks.txt` (`randomticks.go`): one-chunk worlds whose blocks
  are placed while generating (so the light calculated on load sees them),
  ticked with random ticks: grass and mycelium, crops and stems, sugar
  cane, cacti, bamboo, kelp, cocoa, nether wart, redstone ore, leaves,
  farmland, ice and copper. The file also holds each world's placements
  (`tick -1 place`) and tick speed, from which
  `test/ignis/block/test_random_ticks.mojo` builds it. Dragonfly picks
  random blocks chunk by chunk in map order, so only worlds of one loaded
  chunk are deterministic: everything stays more than four blocks inside
  chunk (0, 0).
- `light.txt` (`light.go`, `features.go`): the sky and block light of a
  world whose features are placed while generating, after loading chunks
  -2..2. Checked by `test/ignis/world/chunk/test_light_features.mojo`
  (against the light engine of `feat/light`).

Regenerate from the repository root:

    (cd interop/behaviour && go run . -out ../../test/data/behaviour)
