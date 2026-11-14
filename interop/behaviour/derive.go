package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
)

// mapSource is a world.BlockSource over a map; missing positions are air.
type mapSource map[cube.Pos]world.Block

func (m mapSource) Block(pos cube.Pos) world.Block {
	if b, ok := m[pos]; ok {
		return b
	}
	return block.Air{}
}

// sides are the four horizontal neighbours in the order the vectors list
// them: north, east, south, west.
var sides = []cube.Face{cube.FaceNorth, cube.FaceEast, cube.FaceSouth, cube.FaceWest}

// stairsOptions are the blocks placed beside the stairs: nothing, oak stairs
// facing each direction, and stone stairs facing north.
func stairsOptions() []world.Block {
	return []world.Block{
		nil,
		block.Stairs{Block: block.Planks{Wood: block.OakWood()}, Facing: cube.North},
		block.Stairs{Block: block.Planks{Wood: block.OakWood()}, Facing: cube.East},
		block.Stairs{Block: block.Planks{Wood: block.OakWood()}, Facing: cube.South},
		block.Stairs{Block: block.Planks{Wood: block.OakWood()}, Facing: cube.West},
		block.Stairs{Block: block.Stone{}, Facing: cube.North},
	}
}

// connectorOptions are the blocks placed beside fences, panes and string.
func connectorOptions() []world.Block {
	return []world.Block{
		nil,
		block.Stone{},
		block.WoodFence{Wood: block.OakWood()},
		block.NetherBrickFence{},
		block.GlassPane{},
		block.WoodFenceGate{Wood: block.OakWood()},
		block.String{},
	}
}

// writeDerive writes Stairs.DeriveState and the DeriveState of the
// connecting blocks for every combination of neighbours. Each line is
// "<kind> <centre facing> <n> <e> <s> <w> <result>", the neighbours being
// indices into the option lists above.
func writeDerive(path string) {
	var sb strings.Builder
	pos := cube.Pos{0, 0, 0}
	opts := stairsOptions()
	for f := cube.Direction(0); f <= 3; f++ {
		centre := block.Stairs{Block: block.Planks{Wood: block.OakWood()}, Facing: f}
		forEach(len(opts), func(idx [4]int) {
			src := mapSource{}
			for i, s := range sides {
				if b := opts[idx[i]]; b != nil {
					src[pos.Side(s)] = b
				}
			}
			d := centre.DeriveState(pos, src).(block.Stairs)
			corner := -1
			for i, c := range block.StairsCorners() {
				if c == d.Corner {
					corner = i
				}
			}
			fmt.Fprintf(&sb, "stairs %d %d %d %d %d %d\n", f, idx[0], idx[1], idx[2], idx[3], corner)
		})
	}
	copts := connectorOptions()
	centres := []struct {
		name string
		b    world.StateDeriver
	}{
		{"wood_fence", block.WoodFence{Wood: block.OakWood()}},
		{"nether_brick_fence", block.NetherBrickFence{}},
		{"glass_pane", block.GlassPane{}},
		{"iron_bars", block.IronBars{}},
		{"string", block.String{}},
	}
	for _, c := range centres {
		forEach(len(copts), func(idx [4]int) {
			src := mapSource{}
			for i, s := range sides {
				if b := copts[idx[i]]; b != nil {
					src[pos.Side(s)] = b
				}
			}
			var bits uint8
			switch d := c.b.DeriveState(pos, src).(type) {
			case block.WoodFence:
				bits = d.Connections.Uint8()
			case block.NetherBrickFence:
				bits = d.Connections.Uint8()
			case block.GlassPane:
				bits = d.Connections.Uint8()
			case block.IronBars:
				bits = d.Connections.Uint8()
			case block.String:
				bits = d.Connections.Uint8()
			}
			fmt.Fprintf(&sb, "%s 0 %d %d %d %d %d\n", c.name, idx[0], idx[1], idx[2], idx[3], bits)
		})
	}
	if err := os.WriteFile(path, []byte(sb.String()), 0o644); err != nil {
		panic(err)
	}
}

// forEach calls f with every combination of four indices below n.
func forEach(n int, f func([4]int)) {
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			for c := 0; c < n; c++ {
				for d := 0; d < n; d++ {
					f([4]int{a, b, c, d})
				}
			}
		}
	}
}
