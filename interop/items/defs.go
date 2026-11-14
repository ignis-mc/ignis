package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/entity/effect"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/world"
)

// fakeConsumer records what Consume does to its consumer. Methods it does
// not override belong to the nil embedded interface and panic; no vanilla
// Consume calls them.
type fakeConsumer struct {
	item.Consumer
	food       int
	saturation float64
	effects    map[string]bool
	removed    map[string]bool
	absorption float64
}

func (c *fakeConsumer) Saturate(food int, saturation float64) {
	c.food, c.saturation = food, saturation
}
func (c *fakeConsumer) AddEffect(e effect.Effect) {
	id, _ := effect.ID(e.Type())
	c.effects[fmt.Sprintf("%d:%d:%d", id, e.Level(), e.Duration()/time.Millisecond)] = true
}
func (c *fakeConsumer) RemoveEffect(t effect.Type) {
	if t == effect.Levitation {
		// The one effect Effects reports: removing it means removing all.
		c.removed["*"] = true
		return
	}
	id, _ := effect.ID(t)
	c.removed[fmt.Sprint(id)] = true
}
func (c *fakeConsumer) Effects() []effect.Effect {
	return []effect.Effect{effect.New(effect.Levitation, 1, time.Second)}
}
func (c *fakeConsumer) Absorption() float64          { return c.absorption }
func (c *fakeConsumer) SetAbsorption(health float64) { c.absorption = health }
func (c *fakeConsumer) Name() string                 { return "consumer" }
func (c *fakeConsumer) SetHeldItems(_, _ item.Stack) {}
func (c *fakeConsumer) HeldItems() (_, _ item.Stack) { return }
func (c *fakeConsumer) UsingItem() bool              { return false }
func (c *fakeConsumer) ReleaseItem()                 {}
func (c *fakeConsumer) UseItem()                     {}
func (c *fakeConsumer) H() *world.EntityHandle       { return nil }
func (c *fakeConsumer) Close() error                 { return nil }

func bits(f float64) string { return fmt.Sprintf("%016x", math.Float64bits(f)) }

func b01(b bool) int {
	if b {
		return 1
	}
	return 0
}

// stackName is "name:meta*count" for a stack, "-" when empty.
func stackName(s item.Stack) string {
	if s.Empty() {
		return "-"
	}
	name, meta := s.Item().EncodeItem()
	return fmt.Sprintf("%s:%d*%d", name, meta, s.Count())
}

// typeName is the Go type name, prefixed with "block." for block types.
func typeName(it world.Item) string {
	t := reflect.TypeOf(it)
	if strings.HasSuffix(t.PkgPath(), "/server/block") {
		return "block." + t.Name()
	}
	return t.Name()
}

// itemDefinitions writes defs.txt: one line per registered item, sorted by
// name and meta, with tab-separated fields:
//
//	name meta type block maxcount durability tool armour consumable food
//	fuel smelt enchant repair compost misc
//
// block is "base:state" for block items (Go's Hash), "-" otherwise. Each of
// the following fields is "-" when the item does not implement the
// interface: durability "max,attack,break,persistent,broken"; tool
// "type,level,eff(stone),eff(cobweb)" (efficiencies as float bits);
// armour "slot,defence,toughness,knockback" (slot h/c/l/b, float bits);
// consumable "always,duration_ms"; food "nutrition,saturation bits;effects;
// removed;returned", effects "id:level:ms" sorted and seen in 200 calls,
// removed effect IDs or "*" for every effect;
// fuel "duration_ms,residue"; smelt "product,xp bits,food,ores"; enchant
// the enchantment value; repair the sorted names of registered items whose
// stack repairs it; compost the chance's bits; misc "offhand,beacon,attack
// bits,cooldown_ms" with "-" for each absent part.
func itemDefinitions(out string) {
	all := world.Items()
	sort.Slice(all, func(i, j int) bool {
		ni, mi := all[i].EncodeItem()
		nj, mj := all[j].EncodeItem()
		if ni != nj {
			return ni < nj
		}
		return mi < mj
	})
	var b strings.Builder
	for _, it := range all {
		name, meta := it.EncodeItem()
		f := []string{name, fmt.Sprint(meta), typeName(it)}

		if bl, ok := it.(world.Block); ok {
			base, state := bl.Hash()
			f = append(f, fmt.Sprintf("%d:%d", base, state))
		} else {
			f = append(f, "-")
		}

		mc := 64
		if m, ok := it.(item.MaxCounter); ok {
			mc = m.MaxCount()
		}
		f = append(f, fmt.Sprint(mc))

		if d, ok := it.(item.Durable); ok {
			info := d.DurabilityInfo()
			broken := "-"
			if info.BrokenItem != nil {
				broken = stackName(info.BrokenItem())
			}
			f = append(f, fmt.Sprintf("%d,%d,%d,%d,%s", info.MaxDurability, info.AttackDurability, info.BreakDurability, b01(info.Persistent), broken))
		} else {
			f = append(f, "-")
		}

		if t, ok := it.(item.Tool); ok {
			f = append(f, fmt.Sprintf("%d,%d,%s,%s", toolType(t.ToolType()), t.HarvestLevel(), bits(t.BaseMiningEfficiency(block.Stone{})), bits(t.BaseMiningEfficiency(block.Cobweb{}))))
		} else {
			f = append(f, "-")
		}

		if a, ok := it.(item.Armour); ok {
			slot := "?"
			switch it.(type) {
			case item.HelmetType:
				slot = "h"
			case item.ChestplateType:
				slot = "c"
			case item.LeggingsType:
				slot = "l"
			case item.BootsType:
				slot = "b"
			}
			f = append(f, fmt.Sprintf("%s,%s,%s,%s", slot, bits(a.DefencePoints()), bits(a.Toughness()), bits(a.KnockBackResistance())))
		} else {
			f = append(f, "-")
		}

		if c, ok := it.(item.Consumable); ok {
			f = append(f, fmt.Sprintf("%d,%d", b01(c.AlwaysConsumable()), c.ConsumeDuration()/time.Millisecond))
			f = append(f, food(c))
		} else {
			f = append(f, "-", "-")
		}

		if fu, ok := it.(item.Fuel); ok {
			info := fu.FuelInfo()
			f = append(f, fmt.Sprintf("%d,%s", info.Duration/time.Millisecond, stackName(info.Residue)))
		} else {
			f = append(f, "-")
		}

		if s, ok := it.(item.Smeltable); ok {
			info := s.SmeltInfo()
			f = append(f, fmt.Sprintf("%s,%s,%d,%d", stackName(info.Product), bits(info.Experience), b01(info.Food), b01(info.Ores)))
		} else {
			f = append(f, "-")
		}

		if e, ok := it.(item.Enchantable); ok {
			f = append(f, fmt.Sprint(e.EnchantmentValue()))
		} else {
			f = append(f, "-")
		}

		if r, ok := it.(item.Repairable); ok {
			var names []string
			seen := map[string]bool{}
			for _, other := range all {
				n, _ := other.EncodeItem()
				if !seen[n] && r.RepairableBy(item.NewStack(other, 1)) {
					seen[n] = true
					names = append(names, n)
				}
			}
			sort.Strings(names)
			if len(names) == 0 {
				names = []string{"none"}
			}
			f = append(f, strings.Join(names, ","))
		} else {
			f = append(f, "-")
		}

		if c, ok := it.(item.Compostable); ok {
			f = append(f, bits(c.CompostChance()))
		} else {
			f = append(f, "-")
		}

		misc := []string{"-", "-", "-", "-"}
		if o, ok := it.(item.OffHand); ok {
			misc[0] = fmt.Sprint(b01(o.OffHand()))
		}
		if p, ok := it.(item.BeaconPayment); ok {
			misc[1] = fmt.Sprint(b01(p.PayableForBeacon()))
		}
		if w, ok := it.(item.Weapon); ok {
			misc[2] = bits(w.AttackDamage())
		}
		if c, ok := it.(item.Cooldown); ok {
			misc[3] = fmt.Sprintf("%d", c.Cooldown()/time.Millisecond)
		}
		f = append(f, strings.Join(misc, ","))

		b.WriteString(strings.Join(f, "\t") + "\n")
	}
	must(os.WriteFile(filepath.Join(out, "defs.txt"), []byte(b.String()), 0o644))
}

// toolType returns the unexported value behind a ToolType (-1 for none).
func toolType(t item.ToolType) int {
	switch t {
	case item.TypePickaxe:
		return 0
	case item.TypeAxe:
		return 1
	case item.TypeHoe:
		return 2
	case item.TypeShovel:
		return 3
	case item.TypeShears:
		return 4
	case item.TypeSword:
		return 5
	}
	return -1
}

// food consumes the item 200 times and reports the union of what happened.
func food(c item.Consumable) string {
	fc := &fakeConsumer{effects: map[string]bool{}, removed: map[string]bool{}}
	ret := "-"
	for i := 0; i < 200; i++ {
		s := c.Consume(nil, fc)
		ret = stackName(s)
	}
	keys := func(m map[string]bool) string {
		var out []string
		for k := range m {
			out = append(out, k)
		}
		sort.Strings(out)
		if len(out) == 0 {
			return "-"
		}
		return strings.Join(out, ",")
	}
	return fmt.Sprintf("%d,%s;%s;%s;%s", fc.food, bits(fc.saturation), keys(fc.effects), keys(fc.removed), ret)
}
