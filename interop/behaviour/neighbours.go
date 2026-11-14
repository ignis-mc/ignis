package main

import (
	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/item"
	"github.com/df-mc/dragonfly/server/world"
)

// neighbourScenarios are worlds without random ticks in which blocks fall
// or break when their neighbours change. The Mojo side
// (test/ignis/block/test_neighbour_vectors.mojo) builds the same worlds.
func neighbourScenarios() []scenario {
	lo, hi := cube.Pos{-4, -63, -4}, cube.Pos{16, -54, 12}
	water := block.Water{Depth: 8, Still: true}
	return []scenario{
		{
			name:  "falling",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetBlock(cube.Pos{0, -55, 0}, block.Sand{}, nil)
				tx.SetBlock(cube.Pos{2, -58, 0}, block.Gravel{}, nil)
				tx.SetBlock(cube.Pos{2, -57, 0}, block.Gravel{}, nil)
				tx.SetBlock(cube.Pos{2, -56, 0}, block.Sand{Red: true}, nil)
				tx.SetBlock(cube.Pos{4, -61, 0}, block.Torch{Facing: cube.FaceDown}, nil)
				tx.SetBlock(cube.Pos{4, -57, 0}, block.Sand{}, nil)
				tx.SetLiquid(cube.Pos{6, -61, 0}, water)
				tx.SetBlock(cube.Pos{6, -57, 0}, block.ConcretePowder{Colour: item.ColourRed()}, nil)
				tx.SetBlock(cube.Pos{8, -60, 0}, block.DragonEgg{}, nil)
				tx.SetBlock(cube.Pos{10, -61, 0}, block.ConcretePowder{}, nil)
				tx.SetLiquid(cube.Pos{11, -61, 0}, water)
			},
			checkpoints: []int{1, 2, 3, 5, 8, 12, 20, 30, 45},
			lo:          lo, hi: hi,
		},
		{
			name:  "pops",
			speed: -1,
			setup: func(tx *world.Tx) {
				tx.SetBlock(cube.Pos{0, -61, 3}, block.Torch{Facing: cube.FaceDown}, nil)
				tx.SetBlock(cube.Pos{2, -61, 3}, block.Flower{}, nil)
				tx.SetBlock(cube.Pos{4, -61, 3}, block.DoubleTallGrass{}, nil)
				tx.SetBlock(cube.Pos{4, -60, 3}, block.DoubleTallGrass{UpperPart: true}, nil)
				tx.SetBlock(cube.Pos{6, -61, 3}, block.WoodDoor{}, nil)
				tx.SetBlock(cube.Pos{6, -60, 3}, block.WoodDoor{Top: true}, nil)
				tx.SetLiquid(cube.Pos{9, -62, 3}, water)
				tx.SetBlock(cube.Pos{8, -61, 3}, block.SugarCane{}, nil)
				tx.SetBlock(cube.Pos{8, -60, 3}, block.SugarCane{}, nil)
				tx.SetBlock(cube.Pos{10, -62, 3}, block.Sand{}, nil)
				tx.SetBlock(cube.Pos{10, -63, 3}, block.Stone{}, nil)
				tx.SetBlock(cube.Pos{10, -61, 3}, block.Cactus{}, nil)
				tx.SetBlock(cube.Pos{12, -61, 3}, block.Lantern{}, nil)
				tx.SetBlock(cube.Pos{14, -61, 3}, block.Carpet{}, nil)
				tx.SetBlock(cube.Pos{0, -62, 6}, block.Farmland{}, nil)
				tx.SetBlock(cube.Pos{2, -61, 6}, block.Leaves{}, nil)
				tx.SetLiquid(cube.Pos{4, -61, 8}, water)
			},
			checkpoints: []int{1, 3, 8},
			lo:          lo, hi: hi,
		},
	}
}

// popsChanges are applied to "pops" after tick 8, then the world ticks to
// the checkpoints in popsLater.
func popsChanges(tx *world.Tx) {
	tx.SetBlock(cube.Pos{0, -62, 3}, nil, nil)
	tx.SetBlock(cube.Pos{2, -62, 3}, nil, nil)
	tx.SetBlock(cube.Pos{4, -61, 3}, nil, nil)
	tx.SetBlock(cube.Pos{6, -62, 3}, nil, nil)
	tx.SetLiquid(cube.Pos{9, -62, 3}, nil)
	tx.SetBlock(cube.Pos{11, -61, 3}, block.Stone{}, nil)
	tx.SetBlock(cube.Pos{12, -62, 3}, nil, nil)
	tx.SetBlock(cube.Pos{14, -62, 3}, nil, nil)
	tx.SetBlock(cube.Pos{0, -61, 6}, block.Stone{}, nil)
	tx.SetBlock(cube.Pos{5, -61, 8}, block.Sponge{}, nil)
}

var popsLater = []int{9, 10, 12, 20}
