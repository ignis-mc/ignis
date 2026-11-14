// Command health writes test vectors for Ignis's survival mechanics from
// Dragonfly v0.11.6: armour and enchantment damage reduction and knock-back
// resistance, and experience levels.
//
// Usage (from the repository root):
//
//	(cd interop/health && go run . -out ../../test/data/health)
package main

import (
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/entity/effect"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/enchantment"
	"github.com/df-mc/dragonfly/server/item/inventory"
	"github.com/df-mc/dragonfly/server/player"
	"github.com/df-mc/dragonfly/server/world"
)

func bits(v float64) string { return fmt.Sprintf("%016x", math.Float64bits(v)) }

// armourSet is a named set of worn armour; the Mojo test builds the same
// sets by name.
type armourSet struct {
	name  string
	items [4]item.Stack
}

func full(t item.ArmourTier, ench ...item.Enchantment) [4]item.Stack {
	return [4]item.Stack{
		item.NewStack(item.Helmet{Tier: t}, 1).WithEnchantments(ench...),
		item.NewStack(item.Chestplate{Tier: t}, 1).WithEnchantments(ench...),
		item.NewStack(item.Leggings{Tier: t}, 1).WithEnchantments(ench...),
		item.NewStack(item.Boots{Tier: t}, 1).WithEnchantments(ench...),
	}
}

func sets() []armourSet {
	prot := func(l int) item.Enchantment { return item.NewEnchantment(enchantment.Protection, l) }
	mixed := [4]item.Stack{
		item.NewStack(item.Helmet{Tier: item.ArmourTierIron{}}, 1),
		item.NewStack(item.Chestplate{Tier: item.ArmourTierDiamond{}}, 1).WithEnchantments(item.NewEnchantment(enchantment.BlastProtection, 4)),
		item.NewStack(item.Leggings{Tier: item.ArmourTierChain{}}, 1).WithEnchantments(item.NewEnchantment(enchantment.ProjectileProtection, 3)),
		item.NewStack(item.Boots{Tier: item.ArmourTierGold{}}, 1).WithEnchantments(item.NewEnchantment(enchantment.FeatherFalling, 4), item.NewEnchantment(enchantment.FireProtection, 2)),
	}
	return []armourSet{
		{name: "none"},
		{name: "leather", items: full(item.ArmourTierLeather{})},
		{name: "iron", items: full(item.ArmourTierIron{})},
		{name: "diamond", items: full(item.ArmourTierDiamond{})},
		{name: "netherite", items: full(item.ArmourTierNetherite{})},
		{name: "diamond_prot4", items: full(item.ArmourTierDiamond{}, prot(4))},
		{name: "iron_prot2", items: full(item.ArmourTierIron{}, prot(2))},
		{name: "mixed", items: mixed},
	}
}

// sources are the damage sources the Mojo test names the same way.
func sources() []struct {
	name string
	src  world.DamageSource
} {
	return []struct {
		name string
		src  world.DamageSource
	}{
		{"attack", entity.AttackDamageSource{}},
		{"fall", entity.FallDamageSource{}},
		{"projectile", entity.ProjectileDamageSource{}},
		{"explosion", entity.ExplosionDamageSource{}},
		{"fire", block.FireDamageSource{}},
		{"lava", block.LavaDamageSource{}},
		{"void", entity.VoidDamageSource{}},
		{"starvation", player.StarvationDamageSource{}},
		{"instant", effect.InstantDamageSource{}},
		{"lightning", entity.LightningDamageSource{}},
	}
}

func main() {
	out := flag.String("out", "../../test/data/health", "output directory")
	flag.Parse()
	world.DefaultBlockRegistry.Finalize()
	if err := os.MkdirAll(*out, 0o755); err != nil {
		panic(err)
	}
	var b strings.Builder
	for _, s := range sets() {
		a := inventory.NewArmour(nil)
		a.Set(s.items[0], s.items[1], s.items[2], s.items[3])
		fmt.Fprintf(&b, "kb\t%s\t%s\n", s.name, bits(a.KnockBackResistance()))
		for _, src := range sources() {
			for _, dmg := range []float64{1, 4, 7.5, 13, 20, 40} {
				fmt.Fprintf(&b, "armour\t%s\t%s\t%s\t%s\n", s.name, src.name, bits(dmg), bits(a.DamageReduction(dmg, src.src)))
			}
		}
	}
	for _, amount := range []int{0, 1, 6, 7, 16, 100, 315, 352, 1395, 1508, 5000, 30000} {
		m := entity.NewExperienceManager()
		lvl, prog := m.Add(amount)
		fmt.Fprintf(&b, "xp\t%d\t%d\t%s\n", amount, lvl, bits(prog))
	}
	if err := os.WriteFile(filepath.Join(*out, "damage.txt"), []byte(b.String()), 0o644); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(*out, "living.txt"), []byte(living()), 0o644); err != nil {
		panic(err)
	}
}
