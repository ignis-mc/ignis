# Entity test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`), builds synchronous
flat worlds seeded with `rand.NewPCG(1, 2)` and records:

- `flights.txt`: one projectile, lit TNT, experience orb or firework per
  scenario, spawned with a fixed position and velocity and ticked; every
  tick its position and velocity as float64 bits, then the blocks that
  differ from the flat world. Checked by
  `test/ignis/entity/test_projectile.mojo`.
- `explosions.txt` (`explosions.go`): explosions with a generator seeded
  with (1, 2): the blocks left, the total of dropped items and the other
  entities. Checked by `test/ignis/block/test_explosion.mojo`.

Things Dragonfly draws from Go's global source (orb counts of bottles o'
enchanting, firework flight time, TNT's starting push, lightning) are kept
out of the recorded values.

Regenerate from the repository root:

    (cd interop/entities && go run . -out ../../test/data/entities)
