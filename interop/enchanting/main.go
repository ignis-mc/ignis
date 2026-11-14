// Command enchanting prints the enchanting table offers Dragonfly v0.11.6
// computes for seeds, items and bookshelf counts, for Ignis's test vectors.
// determineAvailableEnchantments and createEnchantments are unexported in
// Dragonfly's session package, so their bodies are copied here verbatim;
// the enchantment data and the random source are Dragonfly's and Go's.
package main

import (
	"fmt"
	"math"
	"math/rand/v2"
	"slices"
	"strings"

	"github.com/df-mc/dragonfly/server/item"
	_ "github.com/df-mc/dragonfly/server/item/enchantment"
	"github.com/df-mc/dragonfly/server/world"
)

type treasureEnchantment interface {
	item.EnchantmentType
	Treasure() bool
}

func offers(stack item.Stack, seed int64, bookshelves int) ([]int, [][]item.Enchantment) {
	enchantable, ok := stack.Item().(item.Enchantable)
	if !ok {
		return nil, nil
	}
	s := uint64(seed)
	random := rand.New(rand.NewPCG(s, s))
	value := enchantable.EnchantmentValue()
	baseCost := random.IntN(8) + 1 + (bookshelves >> 1) + random.IntN(bookshelves+1)
	upper := max(baseCost/3, 1)
	middle := baseCost*2/3 + 1
	lower := max(baseCost, bookshelves*2)
	return []int{upper, middle, lower}, [][]item.Enchantment{
		create(random, stack, value, upper),
		create(random, stack, value, middle),
		create(random, stack, value, lower),
	}
}

func create(random *rand.Rand, stack item.Stack, value, level int) []item.Enchantment {
	randomBonus := (random.Float64() + random.Float64() - 1.0) * 0.15
	cost := level + 1 + random.IntN(value/4+1) + random.IntN(value/4+1)
	cost = min(max(int(math.Round(float64(cost)+float64(cost)*randomBonus)), 1), math.MaxInt32)
	it := stack.Item()
	_, book := it.(item.Book)
	available := make([]item.Enchantment, 0)
	for _, enchant := range item.Enchantments() {
		if t, ok := enchant.(treasureEnchantment); ok && t.Treasure() {
			continue
		}
		if !book && !enchant.CompatibleWithItem(it) {
			continue
		}
		for i := enchant.MaxLevel(); i > 0; i-- {
			if minCost, maxCost := enchant.Cost(i); cost >= minCost && cost <= maxCost {
				available = append(available, item.NewEnchantment(enchant, i))
				break
			}
		}
	}
	if len(available) == 0 {
		return nil
	}
	selected := make([]item.Enchantment, 0)
	enchant := weighted(random, available)
	selected = append(selected, enchant)
	ind := slices.Index(available, enchant)
	available = slices.Delete(available, ind, ind+1)
	for random.IntN(50) <= cost {
		last := selected[len(selected)-1]
		kept := available[:0:0]
		for _, e := range available {
			if last.Type().CompatibleWithEnchantment(e.Type()) {
				kept = append(kept, e)
			}
		}
		available = kept
		if len(available) == 0 {
			break
		}
		enchant = weighted(random, available)
		selected = append(selected, enchant)
		ind = slices.Index(available, enchant)
		available = slices.Delete(available, ind, ind+1)
		cost /= 2
	}
	return selected
}

func weighted(rs *rand.Rand, enchants []item.Enchantment) item.Enchantment {
	var total int
	for _, e := range enchants {
		total += e.Type().Rarity().Weight()
	}
	r := rs.IntN(total)
	for _, e := range enchants {
		r -= e.Type().Rarity().Weight()
		if r < 0 {
			return e
		}
	}
	panic("unreachable")
}

func main() {
	items := []struct {
		name string
		it   world.Item
	}{
		{"diamond_pickaxe", item.Pickaxe{Tier: item.ToolTierDiamond}},
		{"iron_sword", item.Sword{Tier: item.ToolTierIron}},
		{"diamond_helmet", item.Helmet{Tier: item.ArmourTierDiamond{}}},
		{"bow", item.Bow{}},
		{"book", item.Book{}},
	}
	for _, seed := range []int64{1, 42, 123456789, 9223372036854775807} {
		for _, shelves := range []int{0, 7, 15} {
			for _, e := range items {
				costs, enchants := offers(item.NewStack(e.it, 1), seed, shelves)
				var parts []string
				for i := range 3 {
					var ids []string
					for _, en := range enchants[i] {
						id, _ := item.EnchantmentID(en.Type())
						ids = append(ids, fmt.Sprintf("%d:%d", id, en.Level()))
					}
					parts = append(parts, fmt.Sprintf("%d=%s", costs[i], strings.Join(ids, ",")))
				}
				fmt.Printf("%d %d %s %s\n", seed, shelves, e.name, strings.Join(parts, " "))
			}
		}
	}
}
