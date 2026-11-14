package main

import (
	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
)

// randomTickScenarios are worlds of one chunk whose blocks are placed while
// generating, ticked with random ticks. Dragonfly picks random blocks chunk
// by chunk in map order, so a world of more than one loaded chunk would
// draw its random numbers in a different order every run; everything here
// stays inside chunk (0, 0), more than four blocks from its edges. The
// placements and tick speed are written to the vector file, from which the
// Mojo test (test/ignis/block/test_random_ticks.mojo) builds the same worlds.
func randomTickScenarios() []scenario {
	lo, hi := cube.Pos{0, -63, 0}, cube.Pos{15, -55, 15}
	water := block.Water{Depth: 8, Still: true}
	mk := func(name string, speed int, checkpoints []int, p []placement, noItems bool) scenario {
		return scenario{name: name, speed: speed, checkpoints: checkpoints, lo: lo, hi: hi,
			gen: featureFlat{flat: flat(), placements: p}, noItems: noItems}
	}
	var grass []placement
	grass = append(grass, box(cube.Pos{4, -62, 4}, cube.Pos{11, -62, 11}, block.Dirt{})...)
	grass = append(grass, placement{cube.Pos{8, -62, 8}, block.Grass{}})
	grass = append(grass, placement{cube.Pos{5, -62, 5}, block.Dirt{Coarse: true}})
	grass = append(grass, placement{cube.Pos{10, -62, 6}, block.Grass{}})
	grass = append(grass, placement{cube.Pos{10, -61, 6}, block.Stone{}})
	grass = append(grass, placement{cube.Pos{6, -62, 10}, block.Mycelium{}})

	var crops []placement
	crops = append(crops, box(cube.Pos{4, -62, 4}, cube.Pos{10, -62, 10}, block.Farmland{Hydration: 7})...)
	crops = append(crops, placement{cube.Pos{5, -62, 5}, water})
	crops = append(crops, box(cube.Pos{4, -61, 4}, cube.Pos{6, -61, 6}, block.WheatSeeds{})...)
	crops = append(crops, box(cube.Pos{8, -61, 4}, cube.Pos{10, -61, 5}, block.Carrot{})...)
	crops = append(crops, box(cube.Pos{4, -61, 8}, cube.Pos{5, -61, 10}, block.Potato{})...)
	crops = append(crops, box(cube.Pos{8, -61, 8}, cube.Pos{9, -61, 9}, block.BeetrootSeeds{})...)
	crops = append(crops, placement{cube.Pos{10, -61, 10}, block.MelonSeeds{Direction: cube.FaceDown}})
	crops = append(crops, placement{cube.Pos{6, -61, 10}, block.PumpkinSeeds{Direction: cube.FaceDown}})
	crops = append(crops, box(cube.Pos{11, -62, 9}, cube.Pos{11, -62, 11}, block.Farmland{})...)
	crops = append(crops, placement{cube.Pos{11, -61, 10}, block.WheatSeeds{}})

	var plants []placement
	plants = append(plants, box(cube.Pos{4, -62, 4}, cube.Pos{6, -62, 4}, block.Sand{})...)
	plants = append(plants, placement{cube.Pos{5, -62, 4}, water})
	plants = append(plants, placement{cube.Pos{4, -61, 4}, block.SugarCane{}})
	plants = append(plants, placement{cube.Pos{6, -61, 4}, block.SugarCane{Age: 14}})
	plants = append(plants, placement{cube.Pos{9, -62, 4}, block.Sand{}})
	plants = append(plants, placement{cube.Pos{9, -61, 4}, block.Cactus{Age: 10}})
	plants = append(plants, placement{cube.Pos{4, -61, 8}, block.BambooSapling{}})
	plants = append(plants, placement{cube.Pos{6, -61, 8}, block.Bamboo{}})
	plants = append(plants, placement{cube.Pos{6, -60, 8}, block.Bamboo{LeafSize: block.BambooSizeSmallLeaves()}})
	plants = append(plants, box(cube.Pos{9, -62, 8}, cube.Pos{9, -58, 8}, water)...)
	plants = append(plants, placement{cube.Pos{9, -62, 8}, block.Kelp{}})
	plants = append(plants, box(cube.Pos{8, -62, 7}, cube.Pos{10, -57, 7}, block.Glass{})...)
	plants = append(plants, box(cube.Pos{8, -62, 9}, cube.Pos{10, -57, 9}, block.Glass{})...)
	plants = append(plants, box(cube.Pos{8, -62, 8}, cube.Pos{8, -57, 8}, block.Glass{})...)
	plants = append(plants, box(cube.Pos{10, -62, 8}, cube.Pos{10, -57, 8}, block.Glass{})...)
	plants = append(plants, box(cube.Pos{4, -61, 11}, cube.Pos{4, -58, 11}, block.Log{Wood: block.JungleWood()})...)
	plants = append(plants, placement{cube.Pos{5, -60, 11}, block.CocoaBean{Facing: cube.West}})
	plants = append(plants, placement{cube.Pos{8, -62, 11}, block.SoulSand{}})
	plants = append(plants, placement{cube.Pos{8, -61, 11}, block.NetherWart{}})
	plants = append(plants, placement{cube.Pos{11, -61, 11}, block.RedstoneOre{Lit: true}})

	var decay []placement
	decay = append(decay, box(cube.Pos{4, -61, 4}, cube.Pos{4, -57, 4}, block.Log{})...)
	decay = append(decay, box(cube.Pos{5, -57, 3}, cube.Pos{7, -57, 5}, block.Leaves{ShouldUpdate: true})...)
	decay = append(decay, box(cube.Pos{10, -58, 10}, cube.Pos{11, -58, 11}, block.Leaves{ShouldUpdate: true})...)
	decay = append(decay, placement{cube.Pos{11, -57, 10}, block.Leaves{Persistent: true, ShouldUpdate: true}})
	decay = append(decay, box(cube.Pos{5, -62, 9}, cube.Pos{7, -62, 9}, block.Farmland{Hydration: 2})...)
	decay = append(decay, placement{cube.Pos{6, -61, 9}, block.WheatSeeds{}})
	decay = append(decay, placement{cube.Pos{8, -61, 12}, block.Ice{}})
	decay = append(decay, placement{cube.Pos{9, -61, 12}, block.Glowstone{}})
	decay = append(decay, placement{cube.Pos{5, -61, 12}, block.Ice{}})

	var copper []placement
	copper = append(copper, box(cube.Pos{4, -61, 4}, cube.Pos{6, -61, 6}, block.Copper{})...)
	copper = append(copper, placement{cube.Pos{5, -60, 5}, block.Copper{Oxidation: block.WeatheredOxidation()}})
	copper = append(copper, placement{cube.Pos{4, -60, 4}, block.Copper{Waxed: true}})
	copper = append(copper, placement{cube.Pos{6, -60, 6}, block.CopperGrate{}})
	// Copper among more oxidised copper oxidises quickly.
	copper = append(copper, placement{cube.Pos{10, -61, 10}, block.Copper{}})
	copper = append(copper, placement{cube.Pos{10, -60, 10}, block.CopperBars{}})
	for _, p := range []cube.Pos{{11, -61, 10}, {9, -61, 10}, {10, -61, 11}, {10, -61, 9}} {
		copper = append(copper, placement{p, block.Copper{Oxidation: block.ExposedOxidation()}})
	}
	copper = append(copper, placement{cube.Pos{11, -60, 11}, block.CopperGrate{Oxidation: block.WeatheredOxidation()}})

	return []scenario{
		mk("grass", 40, []int{10, 30, 60}, grass, false),
		mk("crops", 60, []int{10, 30, 60, 100}, crops, false),
		mk("plants", 60, []int{10, 30, 60, 100}, plants, false),
		mk("decay", 60, []int{10, 30, 60}, decay, true),
		mk("copper", 2000, []int{20, 100, 300}, copper, false),
	}
}

var _ = world.Liquid(nil)
