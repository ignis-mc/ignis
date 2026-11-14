# Survival test vectors

`main.go` imports Dragonfly v0.11.6 (pinned in `go.mod`) and writes
`test/data/health/damage.txt`:

- `armour <set> <source> <damage> <reduction>`: `inventory.Armour`
  `DamageReduction` for named armour sets (tiers, protection enchantments)
  and damage sources, as float64 bits; `kb <set> <resistance>`. Checked by
  `test/ignis/item/inventory/test_armour.mojo`.
- `xp <amount> <level> <progress>`: `ExperienceManager.Add`. Checked by
  `test/ignis/entity/test_experience.mojo`.

Regenerate from the repository root:

    (cd interop/health && go run . -out ../../test/data/health)
