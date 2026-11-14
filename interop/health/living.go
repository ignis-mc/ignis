package main

import (
	"fmt"
	"math/rand/v2"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/entity/effect"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/inventory"
	"github.com/df-mc/dragonfly/server/player"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/biome"
	"github.com/df-mc/dragonfly/server/world/generator"
	"github.com/go-gl/mathgl/mgl64"
	"github.com/google/uuid"
)

// livingScenario ticks a Dragonfly player (without a session) standing on
// the flat world. Dragonfly's attack immunity is wall-clock time, so every
// tick sleeps 50 ms, as the server's ticks would take.
type livingScenario struct {
	name  string
	conf  func(c *player.Config)
	setup func(p *player.Player)
	ticks int
}

func livingScenarios() []livingScenario {
	diamond := func(c *player.Config) {
		a := inventory.NewArmour(nil)
		a.Set(item.NewStack(item.Helmet{Tier: item.ArmourTierDiamond{}}, 1), item.NewStack(item.Chestplate{Tier: item.ArmourTierDiamond{}}, 1),
			item.NewStack(item.Leggings{Tier: item.ArmourTierDiamond{}}, 1), item.NewStack(item.Boots{Tier: item.ArmourTierDiamond{}}, 1))
		c.Armour = a
	}
	return []livingScenario{
		{name: "starve", ticks: 260, conf: func(c *player.Config) { c.Food, c.FoodTick, c.Saturation = 0, 1, 0 }},
		{name: "regen_saturated", ticks: 120, conf: func(c *player.Config) { c.Health, c.MaxHealth = 10, 20 }},
		{name: "regen_slow", ticks: 260, conf: func(c *player.Config) {
			c.Health, c.MaxHealth, c.Food, c.FoodTick, c.Saturation = 10, 20, 18, 1, 0
		}},
		// Dragonfly ticks effects in map order: healing and hurting effects
		// together would depend on it, so they are separate scenarios.
		{name: "regen_effect", ticks: 120, conf: func(c *player.Config) { c.Health, c.MaxHealth = 8, 20 }, setup: func(p *player.Player) {
			p.AddEffect(effect.New(effect.Regeneration, 2, 4*time.Second))
		}},
		{name: "effects", ticks: 140, setup: func(p *player.Player) {
			p.AddEffect(effect.New(effect.Poison, 2, 3*time.Second))
			p.AddEffect(effect.New(effect.Hunger, 3, 5*time.Second))
			p.AddEffect(effect.New(effect.Wither, 1, 6*time.Second))
		}},
		{name: "absorption", ticks: 20, setup: func(p *player.Player) {
			p.AddEffect(effect.New(effect.Absorption, 2, 2*time.Second))
			p.AddEffect(effect.New(effect.HealthBoost, 1, 3*time.Second))
			p.Hurt(6, entity.AttackDamageSource{})
		}},
		{name: "fire", ticks: 90, setup: func(p *player.Player) { p.SetOnFire(3 * time.Second) }},
		{name: "armour_hurt", ticks: 30, conf: diamond, setup: func(p *player.Player) {
			p.Hurt(10, entity.AttackDamageSource{})
			p.Hurt(4, block.LavaDamageSource{})
			p.AddEffect(effect.NewInstant(effect.InstantDamage, 1))
		}},
	}
}

func living() string {
	var b strings.Builder
	for _, s := range livingScenarios() {
		w := world.Config{
			Synchronous:     true,
			RandSource:      rand.NewPCG(1, 2),
			Generator:       generator.NewFlat(biome.Plains{}, []world.Block{block.Grass{}, block.Dirt{}, block.Bedrock{}}),
			RandomTickSpeed: -1,
			Entities:        entity.DefaultRegistry,
		}.New()
		var p *player.Player
		w.Do(func(tx *world.Tx) {
			tx.Block(cube.Pos{0, 0, 0})
			conf := player.Config{Name: "p", UUID: uuid.New(), Position: mgl64.Vec3{0.5, -61, 0.5}}
			if s.conf != nil {
				s.conf(&conf)
			}
			p = tx.AddEntity(world.EntitySpawnOpts{Position: conf.Position}.New(player.Type, conf)).(*player.Player)
			if s.setup != nil {
				s.setup(p)
			}
			record(&b, s.name, 0, p)
		})
		h := p.H()
		for tick := 1; tick <= s.ticks; tick++ {
			time.Sleep(50 * time.Millisecond)
			w.AdvanceTick()
			w.Do(func(tx *world.Tx) {
				e, _ := h.Entity(tx)
				record(&b, s.name, tick, e.(*player.Player))
			})
		}
	}
	return b.String()
}

// record writes "living scenario tick health max absorption food
// saturation exhaustion foodTick".
func record(b *strings.Builder, name string, tick int, p *player.Player) {
	d := p.Data()
	fmt.Fprintf(b, "living\t%s\t%d\t%s\t%s\t%s\t%d\t%s\t%s\t%d\n", name, tick, bits(p.Health()), bits(p.MaxHealth()),
		bits(p.Absorption()), d.Food, bits(d.Saturation), bits(d.Exhaustion), d.FoodTick)
}
