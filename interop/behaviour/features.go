package main

import (
	"github.com/df-mc/dragonfly/server/block"
	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/chunk"
)

// placement is a block set by featureFlat when it generates a chunk.
type placement struct {
	pos cube.Pos
	b   world.Block
}

// featureFlat is the flat world with blocks placed while generating, so
// that the light calculated when the chunk loads sees them. The Mojo
// generator in test/support/behaviour_vectors.mojo does the same.
type featureFlat struct {
	flat       world.Generator
	placements []placement
}

func (g featureFlat) GenerateChunk(pos world.ChunkPos, c *chunk.Chunk) {
	g.flat.GenerateChunk(pos, c)
	for _, p := range g.placements {
		if p.pos[0]>>4 != int(pos[0]) || p.pos[2]>>4 != int(pos[1]) {
			continue
		}
		c.SetBlock(uint8(p.pos[0]&15), int16(p.pos[1]), uint8(p.pos[2]&15), 0, br.BlockRuntimeID(p.b))
	}
}

func (g featureFlat) DefaultSpawn(d world.Dimension) cube.Pos {
	return g.flat.DefaultSpawn(d)
}

// box returns placements of b filling [lo, hi].
func box(lo, hi cube.Pos, b world.Block) []placement {
	var out []placement
	for y := lo[1]; y <= hi[1]; y++ {
		for z := lo[2]; z <= hi[2]; z++ {
			for x := lo[0]; x <= hi[0]; x++ {
				out = append(out, placement{cube.Pos{x, y, z}, b})
			}
		}
	}
	return out
}

// lightFeatures is the world of the light vectors: a stone roof on pillars
// with glowstone under it, a water pool, leaves, a torch and a wall across
// a chunk border, and glowstone next to the border of chunk (-1, 0).
func lightFeatures() []placement {
	var p []placement
	p = append(p, box(cube.Pos{2, -58, 2}, cube.Pos{8, -58, 8}, block.Stone{})...)
	p = append(p, box(cube.Pos{2, -61, 2}, cube.Pos{2, -59, 2}, block.Stone{})...)
	p = append(p, box(cube.Pos{8, -61, 8}, cube.Pos{8, -59, 8}, block.Stone{})...)
	p = append(p, placement{cube.Pos{5, -61, 5}, block.Glowstone{}})
	p = append(p, box(cube.Pos{10, -62, 10}, cube.Pos{12, -62, 12}, block.Water{Depth: 8, Still: true})...)
	p = append(p, box(cube.Pos{14, -61, 1}, cube.Pos{14, -59, 1}, block.Leaves{})...)
	p = append(p, box(cube.Pos{16, -61, 0}, cube.Pos{16, -55, 15}, block.Stone{})...)
	p = append(p, placement{cube.Pos{20, -61, 4}, block.Torch{Facing: cube.FaceDown}})
	p = append(p, placement{cube.Pos{-1, -61, 8}, block.Glowstone{}})
	p = append(p, box(cube.Pos{-3, -57, -3}, cube.Pos{3, -57, 3}, block.Planks{})...)
	return p
}
