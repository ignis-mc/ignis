package main

import (
	"fmt"
	"math/rand/v2"
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/entity"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/go-gl/mathgl/mgl64"
)

// source is an explosion source at a position (Go's interface).
type source struct {
	pos  mgl64.Vec3
	size float64
}

func (s source) Position() mgl64.Vec3 { return s.pos }
func (s source) Size() float64        { return s.size }

// explosionScenario explodes once with a generator seeded with (1, 2) and
// records the blocks of [lo, hi] that differ from the flat world, then
// "items <count>" (the total of dropped stacks) and every other entity.
type explosionScenario struct {
	name   string
	setup  func(tx *world.Tx)
	src    source
	conf   block.ExplosionConfig
	lo, hi cube.Pos
}

func explosions() string {
	lo, hi := cube.Pos{-10, -64, -10}, cube.Pos{10, -50, 10}
	var b strings.Builder
	for _, s := range []explosionScenario{
		{
			name: "mixed",
			setup: func(tx *world.Tx) {
				for y := -61; y <= -58; y++ {
					tx.SetBlock(cube.Pos{3, y, 0}, block.Stone{}, nil)
					tx.SetBlock(cube.Pos{-3, y, 1}, block.Obsidian{}, nil)
					tx.SetBlock(cube.Pos{0, y, 3}, block.Planks{}, nil)
					tx.SetBlock(cube.Pos{1, y, -3}, block.Glass{}, nil)
				}
				tx.SetBlock(cube.Pos{0, -61, -1}, block.Torch{Facing: cube.FaceDown}, nil)
				tx.SetBlock(cube.Pos{2, -61, 2}, block.TNT{}, nil)
				tx.AddEntity(entity.NewItem(world.EntitySpawnOpts{Position: mgl64.Vec3{1, -61, 1}}, item.NewStack(block.Dirt{}, 3)))
				tx.AddEntity(entity.NewTNT(world.EntitySpawnOpts{Position: mgl64.Vec3{-2, -61, -2}, Velocity: mgl64.Vec3{0, 0.1, 0}}, 1000))
			},
			src: source{pos: mgl64.Vec3{0.5, -60.5, 0.5}, size: 4},
			lo:  lo, hi: hi,
		},
		{
			name: "fire",
			src:  source{pos: mgl64.Vec3{0.5, -61, 0.5}, size: 3},
			conf: block.ExplosionConfig{SpawnFire: true, ItemDropChance: 1},
			lo:   lo, hi: hi,
		},
		{
			name: "water",
			setup: func(tx *world.Tx) {
				for x := -2; x <= 2; x++ {
					for z := -2; z <= 2; z++ {
						tx.SetBlock(cube.Pos{x, -62, z}, block.Water{Depth: 8, Still: true}, &world.SetOpts{DisableBlockUpdates: true})
					}
				}
			},
			src: source{pos: mgl64.Vec3{0.5, -61.5, 0.5}, size: 4},
			lo:  lo, hi: hi,
		},
	} {
		w := newWorld()
		w.Do(func(tx *world.Tx) {
			for cx := -1; cx <= 1; cx++ {
				for cz := -1; cz <= 1; cz++ {
					tx.Block(cube.Pos{cx << 4, 0, cz << 4})
				}
			}
			if s.setup != nil {
				s.setup(tx)
			}
			c := s.conf
			c.RandSource = rand.NewPCG(1, 2)
			c.Explode(tx, s.src)
			for y := s.lo[1]; y <= s.hi[1]; y++ {
				for z := s.lo[2]; z <= s.hi[2]; z++ {
					for x := s.lo[0]; x <= s.hi[0]; x++ {
						rid := br.BlockRuntimeID(tx.Block(cube.Pos{x, y, z}))
						if rid != base(y) {
							fmt.Fprintf(&b, "%s\tblock\t%d,%d,%d\t%d\n", s.name, x, y, z, rid)
						}
					}
				}
			}
			items := 0
			var others []string
			for e := range tx.Entities() {
				ent, ok := e.(*entity.Ent)
				if !ok {
					continue
				}
				if ib, ok := ent.Behaviour().(*entity.ItemBehaviour); ok {
					items += ib.Item().Count()
					continue
				}
				// Lit TNT starts with a push from Go's global source: only its
				// position is recorded.
				others = append(others, fmt.Sprintf("%s\tentity\t%s\t%s\n", s.name, e.H().Type().EncodeEntity(), vec(e.Position())))
			}
			sort.Strings(others)
			fmt.Fprintf(&b, "%s\titems\t%d\n", s.name, items)
			for _, o := range others {
				b.WriteString(o)
			}
		})
	}
	return b.String()
}
