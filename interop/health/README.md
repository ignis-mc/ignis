# Survival test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes
`test/data/health/damage.txt`:

- `armour <set> <source> <damage> <reduction>`: `inventory.Armour`
  `DamageReduction` for named armour sets (tiers, protection enchantments)
  and damage sources, as float64 bits; `kb <set> <resistance>`. Checked by
  `test/ignis/item/inventory/test_armour.mojo`.
- `xp <amount> <level> <progress>`: `ExperienceManager.Add`. Checked by
  `test/ignis/entity/test_experience.mojo`.

- `living.txt` (`living.go`): Dragonfly players (without a session) on
  the flat world, ticked with 50 ms sleeps (its attack immunity is wall
  time): health, maximum, absorption, food, saturation, exhaustion and food
  tick after every tick, for starvation, regeneration, effects, absorption
  and health boost, fire and armoured damage. Dragonfly ticks effects in
  map order, so healing and hurting effects are kept in separate
  scenarios. Checked by `test/ignis/player/test_living.mojo`.

Regenerate from the repository root:

    (cd interop/health && go run . -out ../../test/data/health)
