// Command entities writes test vectors for Ignis's entities from Dragonfly
// v0.11.6: projectiles, TNT, experience orbs and fireworks flying through
// small fixed worlds (positions and velocities every tick, as float64
// bits), the blocks left after they hit, and explosions with a seeded
// generator.
//
// Usage (from the repository root):
//
//	(cd interop/entities && go run . -out ../../test/data/entities)
package main

import (
	"flag"
	"fmt"
	"math"
	"math/rand/v2"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/item/potion"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/biome"
	"github.com/df-mc/dragonfly/server/world/generator"
	"github.com/go-gl/mathgl/mgl64"
)

var br = world.DefaultBlockRegistry

// scenario spawns one entity (spawn) into a flat world prepared by setup,
// ticks it and records it every tick, plus the blocks of [lo, hi] that
// differ from the flat world at the end.
type scenario struct {
	name   string
	setup  func(tx *world.Tx)
	spawn  func(tx *world.Tx, owner world.Entity) *world.EntityHandle
	ticks  int
	lo, hi cube.Pos
}

func main() {
	out := flag.String("out", "../../test/data/entities", "output directory")
	flag.Parse()
	br.Finalize()
	if err := os.MkdirAll(*out, 0o755); err != nil {
		panic(err)
	}
	var b strings.Builder
	for _, s := range scenarios() {
		run(&b, s)
	}
	write(filepath.Join(*out, "flights.txt"), b.String())
	write(filepath.Join(*out, "explosions.txt"), explosions())
}

func write(path, s string) {
	if err := os.WriteFile(path, []byte(s), 0o644); err != nil {
		panic(err)
	}
}

func newWorld() *world.World {
	return world.Config{
		Synchronous:     true,
		RandSource:      rand.NewPCG(1, 2),
		Generator:       generator.NewFlat(biome.Plains{}, []world.Block{block.Grass{}, block.Dirt{}, block.Bedrock{}}),
		RandomTickSpeed: -1,
		Entities:        entity.DefaultRegistry,
	}.New()
}

func bits(v float64) string { return fmt.Sprintf("%016x", math.Float64bits(v)) }

func vec(v mgl64.Vec3) string { return bits(v[0]) + "," + bits(v[1]) + "," + bits(v[2]) }

func run(b *strings.Builder, s scenario) {
	w := newWorld()
	var owner world.Entity
	w.Do(func(tx *world.Tx) {
		for cx := -1; cx <= 1; cx++ {
			for cz := -1; cz <= 1; cz++ {
				tx.Block(cube.Pos{cx << 4, 0, cz << 4})
			}
		}
		if s.setup != nil {
			s.setup(tx)
		}
		owner = tx.AddEntity(entity.NewText("owner", mgl64.Vec3{0, 100, 0}))
		tx.AddEntity(s.spawn(tx, owner))
	})
	for tick := 1; tick <= s.ticks; tick++ {
		w.AdvanceTick()
		w.Do(func(tx *world.Tx) { record(b, s.name, tick, tx) })
	}
	w.Do(func(tx *world.Tx) { blocks(b, s, tx) })
}

// record writes "name tick entity identifier pos vel" for every entity but
// the owner, sorted by identifier and position.
func record(b *strings.Builder, name string, tick int, tx *world.Tx) {
	var lines []string
	for e := range tx.Entities() {
		id := e.H().Type().EncodeEntity()
		if id == "dragonfly:text" {
			continue
		}
		vel := mgl64.Vec3{}
		if v, ok := e.(interface{ Velocity() mgl64.Vec3 }); ok {
			vel = v.Velocity()
		}
		lines = append(lines, fmt.Sprintf("%s\t%d\tentity\t%s\t%s\t%s\n", name, tick, id, vec(e.Position()), vec(vel)))
	}
	sort.Strings(lines)
	if len(lines) == 0 {
		lines = append(lines, fmt.Sprintf("%s\t%d\tnone\n", name, tick))
	}
	for _, l := range lines {
		b.WriteString(l)
	}
}

func base(y int) uint32 {
	switch y {
	case -62:
		return br.BlockRuntimeID(block.Grass{})
	case -63:
		return br.BlockRuntimeID(block.Dirt{})
	case -64:
		return br.BlockRuntimeID(block.Bedrock{})
	}
	return br.AirRuntimeID()
}

func blocks(b *strings.Builder, s scenario, tx *world.Tx) {
	for y := s.lo[1]; y <= s.hi[1]; y++ {
		for z := s.lo[2]; z <= s.hi[2]; z++ {
			for x := s.lo[0]; x <= s.hi[0]; x++ {
				rid := br.BlockRuntimeID(tx.Block(cube.Pos{x, y, z}))
				if rid != base(y) {
					fmt.Fprintf(b, "%s\tend\tblock\t%d,%d,%d\t%d\n", s.name, x, y, z, rid)
				}
			}
		}
	}
}

func scenarios() []scenario {
	lo, hi := cube.Pos{-6, -63, -6}, cube.Pos{12, -55, 6}
	wall := func(tx *world.Tx) {
		for y := -61; y <= -56; y++ {
			for z := -2; z <= 2; z++ {
				tx.SetBlock(cube.Pos{8, y, z}, block.Stone{}, nil)
			}
		}
	}
	opts := func(p, v mgl64.Vec3) world.EntitySpawnOpts {
		return world.EntitySpawnOpts{Position: p, Velocity: v}
	}
	start := mgl64.Vec3{0.5, -59, 0.5}
	return []scenario{
		{name: "snowball", ticks: 40, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewSnowball(opts(start, mgl64.Vec3{0.6, 0.3, 0.1}), o)
		}},
		{name: "egg", ticks: 40, lo: lo, hi: hi, setup: wall, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewEgg(opts(start, mgl64.Vec3{0.9, 0.1, 0}), o)
		}},
		{name: "ender_pearl", ticks: 40, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewEnderPearl(opts(start, mgl64.Vec3{-0.4, 0.5, 0.3}), o)
		}},
		{name: "arrow_wall", ticks: 60, lo: lo, hi: hi, setup: wall, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewArrow(opts(start, mgl64.Vec3{1.5, 0.2, 0.05}), o)
		}},
		{name: "arrow_ground", ticks: 60, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewArrow(opts(start, mgl64.Vec3{0.8, 0.6, -0.3}), o)
		}},
		{name: "splash_water", ticks: 40, lo: lo, hi: hi, setup: func(tx *world.Tx) {
			tx.SetBlock(cube.Pos{4, -61, 0}, block.Fire{}, nil)
			tx.SetBlock(cube.Pos{5, -61, 0}, block.Fire{}, nil)
			tx.SetBlock(cube.Pos{4, -61, 1}, block.Campfire{}, nil)
		}, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewSplashPotion(opts(start, mgl64.Vec3{0.45, 0.2, 0.02}), potion.Water(), o)
		}},
		{name: "lingering", ticks: 40, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewLingeringPotion(opts(start, mgl64.Vec3{0.3, 0.2, 0}), potion.Water(), o)
		}},
		{name: "tnt", ticks: 30, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewTNT(opts(mgl64.Vec3{0.5, -57, 0.5}, mgl64.Vec3{0.05, 0.1, -0.02}), time.Second*2)
		}},
		{name: "xp_orb", ticks: 40, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewExperienceOrb(opts(start, mgl64.Vec3{0.2, 0.3, -0.1}), 7)
		}},
		{name: "firework", ticks: 30, lo: lo, hi: hi, spawn: func(tx *world.Tx, o world.Entity) *world.EntityHandle {
			return entity.NewFirework(opts(start, mgl64.Vec3{0.01, 0.05, 0}), item.Firework{Duration: 2 * time.Second})
		}},
	}
}
