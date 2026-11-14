package main

import (
	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
)

// liquidScenarios are worlds without random ticks in which water and lava
// flow. The Mojo side (test/ignis/block/test_liquid_vectors.mojo) builds the
// same worlds.
func liquidScenarios() []scenario {
	lo, hi := cube.Pos{-10, -63, -10}, cube.Pos{10, -55, 10}
	water := block.Water{Depth: 8, Still: true}
	lava := block.Lava{Depth: 8, Still: true}
	return []scenario{
		{
			name:  "water_flat",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -61, 0}, water)
			},
			checkpoints: []int{1, 6, 7, 12, 20, 40, 80},
			lo:          lo, hi: hi,
		},
		{
			name:  "lava_flat",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -61, 0}, lava)
			},
			checkpoints: []int{31, 62, 120, 200},
			lo:          lo, hi: hi,
		},
		{
			// A hole three blocks away: the water takes the shortest path
			// down and the flat spread stops short of it.
			name:  "water_hole",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetBlock(cube.Pos{3, -62, 1}, nil, nil)
				tx.SetBlock(cube.Pos{3, -63, 1}, nil, nil)
				tx.SetLiquid(cube.Pos{0, -61, 0}, water)
			},
			checkpoints: []int{12, 30, 80},
			lo:          lo, hi: hi,
		},
		{
			// A source in the air falls to the ground and spreads there.
			name:  "water_falls",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -56, 0}, water)
			},
			checkpoints: []int{10, 30, 60, 120},
			lo:          lo, hi: hi,
		},
		{
			// Lava flowing into water and water flowing into lava.
			name:  "lava_meets_water",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -61, 0}, water)
				tx.SetLiquid(cube.Pos{5, -61, 0}, lava)
			},
			checkpoints: []int{20, 40, 80, 160},
			lo:          lo, hi: hi,
		},
		{
			// Water poured on lava from above: the lava source turns to
			// obsidian, flowing lava to cobblestone.
			name:  "water_on_lava",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -61, 0}, lava)
				tx.SetLiquid(cube.Pos{2, -59, 0}, water)
			},
			checkpoints: []int{40, 100, 200},
			lo:          lo, hi: hi,
		},
		{
			// A fence placed in a water source keeps the water (layer 1),
			// which keeps flowing; a fence in flowing water does not.
			name:  "waterlogged",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetLiquid(cube.Pos{0, -61, 0}, water)
				tx.SetBlock(cube.Pos{0, -61, 0}, block.WoodFence{}, nil)
				tx.SetBlock(cube.Pos{2, -61, 0}, block.WoodFence{}, nil)
				tx.SetBlock(cube.Pos{0, -61, 2}, block.Slab{Block: block.Planks{}}, nil)
				tx.SetBlock(cube.Pos{-2, -61, 0}, block.Slab{Block: block.Planks{}, Top: true}, nil)
			},
			checkpoints: []int{12, 40, 80},
			lo:          lo, hi: hi,
		},
		{
			// Water washes away flowers (dropping them) and
			// torches; it stops at stone.
			name:  "water_removes",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetBlock(cube.Pos{1, -61, 0}, block.Flower{}, nil)
				tx.SetBlock(cube.Pos{0, -61, 1}, block.Flower{Type: block.Poppy()}, nil)
				tx.SetBlock(cube.Pos{-1, -61, 0}, block.Stone{}, nil)
				tx.SetBlock(cube.Pos{0, -61, -2}, block.Torch{Facing: cube.FaceDown}, nil)
				tx.SetLiquid(cube.Pos{0, -61, 0}, water)
			},
			checkpoints: []int{7, 13, 40},
			lo:          lo, hi: hi,
		},
	}
}
