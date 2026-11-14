package main

import (
	"bytes"
	"fmt"
	"maps"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/entity/effect"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/enchantment"
	"github.com/df-mc/dragonfly/server/world"
	_ "github.com/df-mc/dragonfly/server/world/biome"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

func rgbaS(r, g, b, a uint8) string { return fmt.Sprintf("%d,%d,%d,%d", r, g, b, a) }

// defsVectors writes defs.txt: biomes, effects and enchantments as
// tab-separated lines starting with their kind.
func defsVectors(out string) {
	var b strings.Builder

	// Biomes, sorted by ID: "biome id type name temperature rainfall depth
	// scale water tags" with floats as IEEE bits.
	bs := world.Biomes()
	sort.Slice(bs, func(i, j int) bool { return bs[i].EncodeBiome() < bs[j].EncodeBiome() })
	for _, bi := range bs {
		w := bi.WaterColour()
		fmt.Fprintf(&b, "biome\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", bi.EncodeBiome(), reflect.TypeOf(bi).Name(), bi.String(),
			f64(bi.Temperature()), f64(bi.Rainfall()), f64(bi.Depth()), f64(bi.Scale()), rgbaS(w.R, w.G, w.B, w.A), strings.Join(bi.Tags(), ","))
	}
	defs, strs := world.BiomeDefinitions()
	var buf bytes.Buffer
	pk := &packet.BiomeDefinitionList{BiomeDefinitions: defs, StringList: strs}
	pk.Marshal(protocol.NewWriter(&buf, 0))
	fmt.Fprintf(&b, "biome_definition_list\t%x\n", buf.Bytes())

	// Effects: "effect id type lasting rgba".
	for id := 0; id < 64; id++ {
		t, ok := effect.ByID(id)
		if !ok {
			continue
		}
		c := t.RGBA()
		_, lasting := t.(effect.LastingType)
		fmt.Fprintf(&b, "effect\t%d\t%s\t%s\t%s\n", id, reflect.TypeOf(t).Name(), boolS(lasting), rgbaS(c.R, c.G, c.B, c.A))
	}
	// ResultingColour: "effect_colour ids;levels;flags -> rgba,ambient";
	// flags: a = ambient, h = particles hidden.
	combos := []struct {
		ids   []int
		flags string
	}{
		{nil, ""}, {[]int{1}, "-"}, {[]int{1, 19}, "--"}, {[]int{1, 19, 6}, "a-h"}, {[]int{14, 16}, "aa"}, {[]int{30}, "h"}, {[]int{5, 10, 11, 12}, "-a-a"},
	}
	for _, c := range combos {
		var effs []effect.Effect
		for i, id := range c.ids {
			t, _ := effect.ByID(id)
			var e effect.Effect
			lt, lasting := t.(effect.LastingType)
			switch {
			case !lasting:
				e = effect.NewInstant(t, 1)
			case c.flags[i] == 'a':
				e = effect.NewAmbient(lt, 1, time.Second)
			default:
				e = effect.New(lt, 1, time.Second)
			}
			if c.flags[i] == 'h' {
				e = e.WithoutParticles()
			}
			effs = append(effs, e)
		}
		col, amb := effect.ResultingColour(effs)
		ids := make([]string, len(c.ids))
		for i, id := range c.ids {
			ids[i] = fmt.Sprint(id)
		}
		fmt.Fprintf(&b, "effect_colour\t%s;%s\t%s,%s\n", strings.Join(ids, ","), c.flags, rgbaS(col.R, col.G, col.B, col.A), boolS(amb))
	}
	// TickDuration of a lasting, an infinite and an instant effect, ticked
	// three times: "effect_tick kind duration_ns tick".
	speed, _ := effect.ByID(1)
	heal, _ := effect.ByID(6)
	ticked := map[string]effect.Effect{
		"lasting":  effect.New(speed.(effect.LastingType), 2, time.Second*3),
		"infinite": effect.NewInfinite(speed.(effect.LastingType), 1),
		"instant":  effect.NewInstant(heal, 3),
	}
	for _, name := range slices.Sorted(maps.Keys(ticked)) {
		e := ticked[name]
		for range 3 {
			e = e.TickDuration()
		}
		fmt.Fprintf(&b, "effect_tick\t%s\t%d\t%d\t%d\t%s\n", name, e.Duration(), e.Tick(), e.Level(), boolS(e.Infinite()))
	}

	// Multipliers of the effects that have one, for levels 0 to 6:
	// "effect_mult id values"; resistance with a source that is reduced
	// by resistance and one that is not.
	for id := 0; id < 64; id++ {
		t, ok := effect.ByID(id)
		if !ok {
			continue
		}
		var vs []string
		if m, ok := t.(interface{ Multiplier(int) float64 }); ok {
			for lvl := range 7 {
				vs = append(vs, f64(m.Multiplier(lvl)))
			}
		}
		if m, ok := t.(interface {
			Multiplier(world.DamageSource, int) float64
		}); ok {
			for lvl := range 7 {
				vs = append(vs, f64(m.Multiplier(effect.PoisonDamageSource{}, lvl)), f64(m.Multiplier(notResisted{}, lvl)))
			}
		}
		if len(vs) > 0 {
			fmt.Fprintf(&b, "effect_mult\t%d\t%s\n", id, strings.Join(vs, ","))
		}
	}
	// Damage sources: "damage_source name resistance armour fire totem".
	sources := map[string]world.DamageSource{
		"PoisonDamageSource": effect.PoisonDamageSource{}, "InstantDamageSource": effect.InstantDamageSource{},
		"WitherDamageSource": effect.WitherDamageSource{}, "ThornsDamageSource": enchantment.ThornsDamageSource{},
	}
	for _, name := range slices.Sorted(maps.Keys(sources)) {
		src := sources[name]
		fmt.Fprintf(&b, "damage_source\t%s\t%s,%s,%s,%s\n", name, boolS(src.ReducedByResistance()), boolS(src.ReducedByArmour()), boolS(src.Fire()), boolS(src.IgnoreTotem()))
	}

	// Items to test CompatibleWithItem with, and their properties:
	// "ench_item index flags tooltype" with flags armour, helmet, chestplate
	// (unused), leggings, boots, bow, crossbow, durable, compass,
	// recovery compass and tooltype the item.Tool type or -2.
	items := []world.Item{
		item.Sword{Tier: item.ToolTierIron}, item.Axe{Tier: item.ToolTierWood}, item.Pickaxe{Tier: item.ToolTierDiamond},
		item.Shovel{Tier: item.ToolTierStone}, item.Hoe{Tier: item.ToolTierGold}, item.Shears{},
		item.Helmet{Tier: item.ArmourTierIron{}}, item.Chestplate{Tier: item.ArmourTierDiamond{}},
		item.Leggings{Tier: item.ArmourTierChain{}}, item.Boots{Tier: item.ArmourTierLeather{}},
		item.Bow{}, item.Crossbow{}, item.Compass{}, item.RecoveryCompass{}, item.FlintAndSteel{}, item.Elytra{},
		item.TurtleShell{}, item.CarrotOnAStick{}, item.Stick{}, item.Diamond{},
	}
	for i, it := range items {
		flags := 0
		set := func(bit int, ok bool) {
			if ok {
				flags |= 1 << bit
			}
		}
		_, armour := it.(item.Armour)
		h, isH := it.(item.HelmetType)
		l, isL := it.(item.LeggingsType)
		bo, isB := it.(item.BootsType)
		_, bow := it.(item.Bow)
		_, crossbow := it.(item.Crossbow)
		_, durable := it.(item.Durable)
		_, compass := it.(item.Compass)
		_, rc := it.(item.RecoveryCompass)
		set(0, armour)
		set(1, isH && h.Helmet())
		set(3, isL && l.Leggings())
		set(4, isB && bo.Boots())
		set(5, bow)
		set(6, crossbow)
		set(7, durable)
		set(8, compass)
		set(9, rc)
		tool := -2
		if t, ok := it.(item.Tool); ok {
			tool = int(reflect.ValueOf(t.ToolType()).Field(0).Int())
		}
		fmt.Fprintf(&b, "ench_item\t%d\t%s\t%d\t%d\n", i, reflect.TypeOf(it).Name(), flags, tool)
	}
	// Enchantments: "enchantment id type name maxlevel rarity(name,cost,weight)
	// costs compatible items extras", costs as min-max per level 1..max+1,
	// compatible the IDs it is compatible with, items the indices of items
	// it applies to.
	var ids []int
	for id := 0; id < 64; id++ {
		if _, ok := item.EnchantmentByID(id); ok {
			ids = append(ids, id)
		}
	}
	for _, id := range ids {
		t, _ := item.EnchantmentByID(id)
		var costs []string
		for lvl := 1; lvl <= t.MaxLevel()+1; lvl++ {
			lo, hi := t.Cost(lvl)
			costs = append(costs, fmt.Sprintf("%d-%d", lo, hi))
		}
		var compat []string
		for _, o := range ids {
			ot, _ := item.EnchantmentByID(o)
			if t.CompatibleWithEnchantment(ot) {
				compat = append(compat, fmt.Sprint(o))
			}
		}
		var its []string
		for i, it := range items {
			if t.CompatibleWithItem(it) {
				its = append(its, fmt.Sprint(i))
			}
		}
		r := t.Rarity()
		var extras []string
		if v, ok := t.(interface{ Treasure() bool }); ok {
			extras = append(extras, "treasure="+boolS(v.Treasure()))
		}
		if v, ok := t.(interface{ Curse() bool }); ok {
			extras = append(extras, "curse="+boolS(v.Curse()))
		}
		if v, ok := t.(interface{ Modifier() float64 }); ok {
			extras = append(extras, "modifier="+f64(v.Modifier()))
		}
		perLevel := func(name string, f func(int) string) {
			var vs []string
			for lvl := 1; lvl <= t.MaxLevel()+1; lvl++ {
				vs = append(vs, f(lvl))
			}
			extras = append(extras, name+"="+strings.Join(vs, ";"))
		}
		if v, ok := t.(interface{ Addend(int) float64 }); ok {
			perLevel("addend", func(l int) string { return f64(v.Addend(l)) })
		}
		if v, ok := t.(interface{ Force(int) float64 }); ok {
			perLevel("force", func(l int) string { return f64(v.Force(l)) })
		}
		if v, ok := t.(interface{ PowerDamage(int) float64 }); ok {
			perLevel("power_damage", func(l int) string { return f64(v.PowerDamage(l)) })
		}
		if v, ok := t.(interface{ Chance(int) float64 }); ok {
			perLevel("chance", func(l int) string { return f64(v.Chance(l)) })
		}
		if v, ok := t.(interface{ Duration(int) time.Duration }); ok {
			perLevel("duration", func(l int) string { return fmt.Sprint(int64(v.Duration(l))) })
		}
		if v, ok := t.(interface{ ChargeDuration(int) time.Duration }); ok {
			perLevel("charge_duration", func(l int) string { return fmt.Sprint(int64(v.ChargeDuration(l))) })
		}
		if v, ok := t.(interface{ BurnDuration() time.Duration }); ok {
			extras = append(extras, "burn_duration="+fmt.Sprint(int64(v.BurnDuration())))
		}
		if v, ok := t.(interface{ KnockBackMultiplier() float64 }); ok {
			extras = append(extras, "knockback_multiplier="+f64(v.KnockBackMultiplier()))
		}
		if v, ok := t.(interface{ ConsumesArrows() bool }); ok {
			extras = append(extras, "consumes_arrows="+boolS(v.ConsumesArrows()))
		}
		if v, ok := t.(interface{ MultipleProjectiles() bool }); ok {
			extras = append(extras, "multiple_projectiles="+boolS(v.MultipleProjectiles()))
		}
		if v, ok := t.(interface{ Pierces() bool }); ok {
			extras = append(extras, "pierces="+boolS(v.Pierces()))
		}
		slices.Sort(extras)
		fmt.Fprintf(&b, "enchantment\t%d\t%s\t%s\t%d\t%s,%d,%d\t%s\t%s\t%s\t%s\n", id, reflect.TypeOf(t).Name(), t.Name(), t.MaxLevel(),
			r.Name(), r.Cost(), r.Weight(), strings.Join(costs, ","), strings.Join(compat, ","), strings.Join(its, ","), strings.Join(extras, " "))
	}
	_ = math.MaxInt
	must(os.WriteFile(filepath.Join(out, "defs.txt"), []byte(b.String()), 0o644))
}

// notResisted is a damage source not reduced by resistance.
type notResisted struct{}

func (notResisted) ReducedByResistance() bool { return false }
func (notResisted) ReducedByArmour() bool     { return false }
func (notResisted) Fire() bool                { return false }
func (notResisted) IgnoreTotem() bool         { return false }
